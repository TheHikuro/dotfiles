# ─── 20-tools.fish — init des outils externes ────────────────────────────────
#
# En nushell il fallait pré-générer des fichiers dans ~/.cache (starship/init.nu,
# carapace/init.nu, .zoxide.nu, mise.nu) parce que nu doit parser le source au
# parse-time. En fish, `<cmd> | source` marche directement — plus de cache à
# gérer, plus de patch `str upcase` pour mise.

# ─── mise (gestion de versions) ──────────────────────────────────────────────
if type -q mise
    mise activate fish | source
end

# ─── zoxide (remplace cd, comme `alias cd = z` en nu) ────────────────────────
if type -q zoxide
    zoxide init fish --cmd cd | source
end

# ─── carapace (completions multi-shell) ──────────────────────────────────────
if status is-interactive; and type -q carapace
    carapace _carapace fish | source
end

# ─── fzf : bindings Ctrl-R / Ctrl-T / Alt-C (bonus, pas d'équivalent nu) ─────
if status is-interactive; and type -q fzf
    fzf --fish | source
end

# ─── starship (prompt) — doit rester en dernier ──────────────────────────────
if status is-interactive; and type -q starship
    starship init fish | source
end
