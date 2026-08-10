# ─── 00-env.fish — équivalent de env.nu ──────────────────────────────────────
# conf.d/*.fish est sourcé automatiquement, dans l'ordre lexical, AVANT
# config.fish, et dans TOUS les shells (login, non-login, interactif ou non).

# ─── base PATH ───────────────────────────────────────────────────────────────
# fish_add_path prepend + dédoublonne tout seul (idempotent).
# -g = global (pas -U : on veut que le repo soit la source de vérité, pas
# ~/.config/fish/fish_variables qui n'est pas versionné).
fish_add_path -gp /opt/homebrew/bin
fish_add_path -gp /opt/homebrew/sbin
fish_add_path -gp /usr/local/bin
fish_add_path -gp $HOME/.local/bin
fish_add_path -gp $HOME/.mise/shims

# ─── ENV vars ────────────────────────────────────────────────────────────────
set -gx EDITOR nvim
set -gx STARSHIP_CONFIG $HOME/.config/starship/starship.toml
set -gx GIT_OPTIONAL_LOCKS 0

# ─── Android SDK (si installé) ───────────────────────────────────────────────
if test -d $HOME/Library/Android/sdk
    set -gx ANDROID_HOME $HOME/Library/Android/sdk
    fish_add_path -ga $ANDROID_HOME/emulator
    fish_add_path -ga $ANDROID_HOME/platform-tools
end

# ─── CARAPACE_BRIDGES (completions multi-shell) ──────────────────────────────
# 'fish' retiré : carapace tourne nativement en fish, se brider soi-même
# ne sert à rien.
set -gx CARAPACE_BRIDGES 'zsh,bash,inshellisense'

# ─── GPG ─────────────────────────────────────────────────────────────────────
# `tty` échoue sans terminal attaché → on garde ça pour les shells interactifs.
if status is-interactive
    set -gx GPG_TTY (tty)
end
