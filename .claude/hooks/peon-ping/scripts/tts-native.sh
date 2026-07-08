#!/bin/bash
# peon-ping: Unix platform-native TTS backend
#
# Routes speech through the OS's built-in TTS engine:
#   Darwin        → macOS `say`
#   Linux         → piper (if installed + model file present) → espeak-ng
#   MINGW*/MSYS*  → bridges to scripts/tts-native.ps1 via powershell.exe
#   anything else → silent exit 0
#
# Usage:
#   echo "text to speak" | tts-native.sh <voice> <rate> <volume>
#   tts-native.sh --list-voices
#
# Positional args:
#   voice   engine-specific voice name (e.g. "Alex" on macOS, "en-us" for
#           espeak-ng, "Microsoft David" on Windows) or "default" for the
#           engine default.
#   rate    float; 1.0 = normal speed, 0.5 = half, 2.0 = double.
#   volume  float 0.0-1.0 (silent .. full). Ignored on macOS `say` and
#           piper+aplay — see docs/designs/tts-native.md §Risks.
#
# Stdin:   one line of text to speak (read verbatim, no interpolation).
# Stdout:  empty during normal invocations. `--list-voices` prints one
#          voice name per line.
# Stderr:  empty unless PEON_DEBUG=1, in which case diagnostics are
#          prefixed with `[tts-native]`.
# Exit:    always 0 — TTS failure must not fail the calling hook.
#
# Env vars:
#   PEON_DEBUG            "1" enables stderr diagnostics
#   PEON_DIR              peon-ping install dir (auto-resolved from $0)
#   PEON_PIPER_MODEL      absolute path to a .onnx model (overrides default)
#   PEON_PIPER_MODEL_DIR  dir scanned by --list-voices for model basenames
#
# See docs/designs/tts-native.md and docs/adr/ADR-001-tts-backend-architecture.md
# for the full specification.

set -uo pipefail

PEON_DEBUG="${PEON_DEBUG:-0}"

_debug() {
  [ "$PEON_DEBUG" = "1" ] && printf '[tts-native] %s\n' "$*" >&2
  return 0
}

# --- Resolve PEON_DIR ---
if [ -z "${PEON_DIR:-}" ]; then
  PEON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

# Documents that $1 is intentionally unused on engines without per-invocation
# volume support (macOS `say`, piper+aplay). Keeps shellcheck quiet and
# makes the omission auditable.
_ignore_unused_volume() {
  :  # arg intentionally unused
}

# --- Engine: macOS `say` ---
_speak_macos() {
  local text="$1" voice="$2" rate="$3" volume="$4"
  _ignore_unused_volume "$volume"

  # Pass rate as awk -v variable so a hostile config.json cannot inject awk
  # code (e.g. a rate string of 'system("...")'). See card w3ciyq.
  local wpm
  wpm=$(awk -v r="$rate" 'BEGIN { printf "%d", r * 200 }')

  if [ "$voice" = "default" ]; then
    say -r "$wpm" -- "$text" 2>/dev/null || _debug "say failed"
  else
    say -v "$voice" -r "$wpm" -- "$text" 2>/dev/null || _debug "say failed"
  fi
}

# --- Engine: piper (neural TTS, Linux preferred path) ---
_speak_piper() {
  local text="$1" model="$2" rate="$3"
  # Pass rate as awk -v variable so a hostile config.json cannot inject awk
  # code via the rate string. See card w3ciyq.
  local length_scale
  length_scale=$(awk -v r="$rate" 'BEGIN { printf "%.2f", 1.0 / r }')

  # Read sample rate from the model's .onnx.json sidecar; default 22050.
  local sidecar="${model}.json"
  local rate_hz=22050
  if [ -f "$sidecar" ]; then
    local parsed
    parsed=$(python3 -c "import json,sys
try:
  with open(sys.argv[1]) as f:
    print(json.load(f)['audio']['sample_rate'])
except Exception:
  sys.exit(1)
" "$sidecar" 2>/dev/null) && rate_hz="$parsed"
  fi

  printf '%s\n' "$text" \
    | piper --model "$model" --length-scale "$length_scale" --output-raw 2>/dev/null \
    | aplay -q -r "$rate_hz" -f S16_LE -t raw 2>/dev/null \
    || _debug "piper pipeline failed"
}

# --- Engine: espeak-ng (Linux fallback) ---
_speak_espeak_ng() {
  local text="$1" voice="$2" rate="$3" volume="$4"
  # Pass rate/volume as awk -v variables so hostile config.json values cannot
  # inject awk code (e.g. a rate string of 'system("...")'). See card w3ciyq.
  local wpm amplitude
  wpm=$(awk -v r="$rate" 'BEGIN { printf "%d", r * 175 }')
  amplitude=$(awk -v v="$volume" 'BEGIN { printf "%d", v * 100 }')

  if [ "$voice" = "default" ]; then
    espeak-ng -s "$wpm" -a "$amplitude" -- "$text" 2>/dev/null || _debug "espeak-ng failed"
  else
    espeak-ng -v "$voice" -s "$wpm" -a "$amplitude" -- "$text" 2>/dev/null || _debug "espeak-ng failed"
  fi
}

# --- Linux dispatcher: piper → espeak-ng → silent exit ---
_speak_linux() {
  local text="$1" voice="$2" rate="$3" volume="$4"

  local piper_model="${PEON_PIPER_MODEL:-$PEON_DIR/piper-models/en_US-lessac-medium.onnx}"
  if command -v piper >/dev/null 2>&1 && [ -f "$piper_model" ]; then
    _speak_piper "$text" "$piper_model" "$rate"
    return 0
  fi

  if command -v espeak-ng >/dev/null 2>&1; then
    _speak_espeak_ng "$text" "$voice" "$rate" "$volume"
    return 0
  fi

  _debug "no TTS engine found on Linux (tried piper, espeak-ng)"
}

# --- MSYS2/MINGW bridge to tts-native.ps1 ---
_speak_via_powershell() {
  local text="$1" voice="$2" rate="$3" volume="$4"
  local ps_script="$PEON_DIR/scripts/tts-native.ps1"
  if [ ! -f "$ps_script" ]; then
    _debug "tts-native.ps1 not found at $ps_script"
    return 0
  fi
  # -File preserves stdin bytes; named params avoid -Command metacharacter
  # issues. Base64 encoding is handled only at the hook→Start-Process boundary
  # on native Windows (Invoke-TtsSpeak), not here.
  printf '%s\n' "$text" \
    | powershell.exe -NoProfile -File "$ps_script" \
        -Voice "$voice" -Rate "$rate" -Vol "$volume" 2>/dev/null \
    || _debug "powershell tts-native.ps1 failed"
}

# --- Voice enumeration per platform ---
_list_voices_macos() {
  # `say -v '?'` emits a whitespace-padded table; first column is the voice.
  say -v '?' 2>/dev/null | awk 'NF { print $1 }'
}

_list_voices_linux() {
  # Piper models (if a model dir is present) ordered first — they take
  # priority as the active engine when installed.
  local piper_dir="${PEON_PIPER_MODEL_DIR:-$PEON_DIR/piper-models}"
  if command -v piper >/dev/null 2>&1 && [ -d "$piper_dir" ]; then
    find "$piper_dir" -maxdepth 1 -name '*.onnx' -print 2>/dev/null \
      | while IFS= read -r m; do
          basename "$m" .onnx
        done | sort
  fi
  if command -v espeak-ng >/dev/null 2>&1; then
    # `espeak-ng --voices` emits a header row + "Pty Language Age/Gender
    # VoiceName File ..." columns; the 4th column is the voice name.
    espeak-ng --voices 2>/dev/null | awk 'NR>1 && $4 != "" { print $4 }'
  fi
}

_list_voices_powershell() {
  local ps_script="$PEON_DIR/scripts/tts-native.ps1"
  if [ ! -f "$ps_script" ]; then
    _debug "tts-native.ps1 not found — cannot list voices"
    return 0
  fi
  powershell.exe -NoProfile -File "$ps_script" -ListVoices 2>/dev/null \
    || _debug "powershell tts-native.ps1 -ListVoices failed"
}

_list_voices() {
  case "$(uname -s)" in
    Darwin)       _list_voices_macos ;;
    Linux)        _list_voices_linux ;;
    MINGW*|MSYS*) _list_voices_powershell ;;
    *)            _debug "unsupported platform: $(uname -s)" ;;
  esac
}

# --- Entry point ---

# List-voices mode runs before stdin read so `--list-voices` does not block
# on a tty.
if [ "${1:-}" = "--list-voices" ]; then
  _list_voices
  exit 0
fi

voice="${1:-default}"
rate="${2:-1.0}"
volume="${3:-0.5}"

# Read one line of text from stdin. If nothing arrives (no input, EOF, or
# whitespace-only line), exit silently — the hook pipeline sometimes invokes
# speak() with empty text and TTS must not complain.
IFS= read -r text || text=""
# Strip surrounding whitespace to detect "whitespace-only" input.
stripped="${text//[[:space:]]/}"
if [ -z "$stripped" ]; then
  _debug "empty input text"
  exit 0
fi

case "$(uname -s)" in
  Darwin)       _speak_macos "$text" "$voice" "$rate" "$volume" ;;
  Linux)        _speak_linux "$text" "$voice" "$rate" "$volume" ;;
  MINGW*|MSYS*) _speak_via_powershell "$text" "$voice" "$rate" "$volume" ;;
  *)            _debug "unsupported platform: $(uname -s)" ;;
esac

# Always exit 0 — TTS failure must never propagate to the caller.
exit 0
