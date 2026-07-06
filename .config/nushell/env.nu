# ─── base PATH  ─────────────────────────────────────────────────────────────
$env.PATH = (
  $env.PATH
  | split row (char esep)
  | prepend "/opt/homebrew/bin"
  | prepend "/opt/homebrew/sbin"
  | prepend "/usr/local/bin"
  | prepend $"($env.HOME)/.local/bin"
  | prepend $"($env.HOME)/.mise/shims"  
  | uniq
  | str join (char esep)
)

# ─── ENV vars ─────────────────────────────────────────────────────────────────
$env.EDITOR          = "nvim"
$env.STARSHIP_CONFIG = $"($env.HOME)/.config/starship/starship.toml"
$env.GIT_OPTIONAL_LOCKS = "0"

# ─── Android SDK (if installed) ────────────────────────────────────────────────
if ($"($env.HOME)/Library/Android/sdk" | path exists) {
  $env.ANDROID_HOME = $"($env.HOME)/Library/Android/sdk"
  $env.PATH = (
    $env.PATH
    | split row (char esep)
    | append $"($env.ANDROID_HOME)/emulator"
    | append $"($env.ANDROID_HOME)/platform-tools"
    | uniq
    | str join (char esep)
  )
}

# ─── CARAPACE_BRIDGES (completions multi-shell) ───────────────────────────────
$env.CARAPACE_BRIDGES = 'zsh,fish,bash,inshellisense'

# ─── Conversions PATH ────────────────────────────────────────────────────────
$env.ENV_CONVERSIONS = {
  "PATH": {
    from_string: { |s| $s | split row (char esep) | path expand --no-symlink }
    to_string:   { |v| $v | path expand --no-symlink | str join (char esep) }
  }
  "Path": {
    from_string: { |s| $s | split row (char esep) | path expand --no-symlink }
    to_string:   { |v| $v | path expand --no-symlink | str join (char esep) }
  }
}

# ─── NuShell lib dirs ────────────────────────────────────────────────────────
$env.NU_LIB_DIRS = [
  ($nu.default-config-dir | path join 'scripts')
  ($nu.data-dir | path join 'completions')
  $nu.default-config-dir    
]
$env.NU_PLUGIN_DIRS = [
  ($nu.default-config-dir | path join 'plugins')
]

# ---- GPG Activation Permanent ----
$env.GPG_TTY = (tty)

# ─── MISE activation ──────────────────────────────────────────────────────────
let mise_path = ($nu.default-config-dir | path join mise.nu)
if not ($mise_path | path exists) {
  # `mise activate nu` still emits the deprecated `str upcase`; patch it on generation
  # so we don't get a parser warning on every prompt until upstream fixes it.
  ^mise activate nu | str replace 'str upcase' 'str uppercase' | save $mise_path --force
}

# ─── Init tools ───────────────────────────────────────────────────────────────
# Use ~/.cache for consistency with ansible
let cache_dir = $"($env.HOME)/.cache"

# Ensure cache directories exist
try { mkdir $"($cache_dir)/starship" }
try { mkdir $"($cache_dir)/carapace" }

# Generate init files only if they don't exist (to avoid timeouts on every session)
if not ($"($cache_dir)/starship/init.nu" | path exists) {
  ^starship init nu | save --force $"($cache_dir)/starship/init.nu"
}

if not ($"($cache_dir)/carapace/init.nu" | path exists) {
  ^carapace _carapace nushell | save --force $"($cache_dir)/carapace/init.nu"
}

source ~/.config/nushell/secrets.nu
zoxide init nushell | save -f ~/.zoxide.nu
source ~/.zoxide.nu
