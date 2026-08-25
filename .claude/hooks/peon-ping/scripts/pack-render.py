#!/usr/bin/env python3
"""Render one pack sound via ElevenLabs -> 44.1kHz mono 16-bit WAV.

Key lookup: ELEVENLABS_API_KEY env -> ~/.config/peon-ping/credentials ->
legacy ~/Documents/github-repos/mypersonalwebsite/.env.local.
Silent-QA: max_volume < -50 dB -> one retry with strengthened prompt -> exit 3.
"""
import argparse, json, math, os, re, struct, subprocess, sys, tempfile, urllib.request, wave

SILENCE_DB = -50.0
RETRY_SUFFIX = ", clearly audible, prominent"

def read_api_key():
    key = os.environ.get("ELEVENLABS_API_KEY", "").strip()
    if key:
        return key
    home = os.path.expanduser("~")
    for path in (os.path.join(home, ".config/peon-ping/credentials"),
                 os.path.join(home, "Documents/github-repos/mypersonalwebsite/.env.local")):
        try:
            with open(path) as f:
                for line in f:
                    if line.startswith("ELEVENLABS_API_KEY="):
                        return line.split("=", 1)[1].strip().strip("\"'")
        except OSError:
            continue
    sys.stderr.write(
        "No ElevenLabs key found. Set ELEVENLABS_API_KEY, or add\n"
        "  ELEVENLABS_API_KEY=<your key>\n"
        "to ~/.config/peon-ping/credentials (get one at https://elevenlabs.io).\n")
    sys.exit(2)

def write_mock(out_path):
    with wave.open(out_path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(44100)
        frames = int(44100 * 1.5)
        w.writeframes(b"".join(
            struct.pack("<h", int(12000 * math.sin(2 * math.pi * 440 * i / 44100) * (1 - i / frames)))
            for i in range(frames)))

def fetch_mp3(job, key, prompt_suffix=""):
    if job["type"] == "sfx":
        url = "https://api.elevenlabs.io/v1/sound-generation"
        body = {"text": job["prompt"] + prompt_suffix, "prompt_influence": 0.3}
        if job.get("duration_seconds"):
            body["duration_seconds"] = job["duration_seconds"]
    else:
        url = "https://api.elevenlabs.io/v1/text-to-speech/%s?output_format=mp3_44100_128" % job["voice_id"]
        body = {"text": job["text"], "model_id": "eleven_multilingual_v2"}
    req = urllib.request.Request(url, data=json.dumps(body).encode(),
                                 headers={"xi-api-key": key, "content-type": "application/json"})
    with urllib.request.urlopen(req, timeout=120) as resp:
        return resp.read()

def to_wav(mp3_bytes, out_path):
    """Convert mp3_bytes to a WAV at out_path. Callers pass a scratch temp path
    here, never the real `out` — see the B4 fix in main()."""
    with tempfile.NamedTemporaryFile(suffix=".mp3", delete=False) as t:
        t.write(mp3_bytes); mp3 = t.name
    try:
        subprocess.run(["ffmpeg", "-y", "-i", mp3, "-ar", "44100", "-ac", "1",
                        "-sample_fmt", "s16", out_path],
                       check=True, capture_output=True)
    finally:
        os.unlink(mp3)

def peak_db(wav_path):
    r = subprocess.run(["ffmpeg", "-i", wav_path, "-af", "volumedetect", "-f", "null", "-"],
                       capture_output=True, text=True)
    m = re.search(r"max_volume:\s*(-?[\d.]+) dB", r.stderr)
    if not m:
        sys.stderr.write("could not parse max_volume from ffmpeg volumedetect output\n")
        sys.exit(1)
    return float(m.group(1))

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--job", required=True)
    ap.add_argument("--mock", action="store_true")
    args = ap.parse_args()
    with open(args.job) as f:
        job = json.load(f)
    if job.get("type") not in ("sfx", "tts") or not job.get("out") \
       or (job["type"] == "sfx" and not job.get("prompt")) \
       or (job["type"] == "tts" and not (job.get("text") and job.get("voice_id"))):
        sys.stderr.write("malformed job: need type sfx(prompt)/tts(text,voice_id) and out\n")
        sys.exit(1)
    os.makedirs(os.path.dirname(job["out"]) or ".", exist_ok=True)
    if args.mock:
        write_mock(job["out"]); return
    key = read_api_key()
    out_dir = os.path.dirname(os.path.abspath(job["out"])) or "."
    for suffix in ("", RETRY_SUFFIX):
        try:
            mp3_bytes = fetch_mp3(job, key, suffix if job["type"] == "sfx" else "")
        except urllib.error.URLError as e:
            sys.stderr.write("ElevenLabs request failed: %s\n" % e.reason)
            sys.exit(1)
        # B4: render to a scratch temp file in the SAME directory as `out`, never
        # `out` itself. A failed/silent take must never truncate or overwrite a
        # previously-good WAV — only a passing render replaces it, atomically.
        tmp_fd, tmp_path = tempfile.mkstemp(suffix=".wav", dir=out_dir)
        os.close(tmp_fd)
        try:
            try:
                to_wav(mp3_bytes, tmp_path)
            except subprocess.CalledProcessError:
                sys.stderr.write("ffmpeg conversion failed\n")
                sys.exit(1)
            if peak_db(tmp_path) >= SILENCE_DB:
                os.replace(tmp_path, job["out"])
                return
        finally:
            try:
                os.unlink(tmp_path)
            except OSError:
                pass
        if job["type"] == "tts":
            break  # strengthened-prompt retry only makes sense for sfx
    sys.stderr.write("silent render after retry: %s\n" % job["out"])
    sys.exit(3)

if __name__ == "__main__":
    main()
