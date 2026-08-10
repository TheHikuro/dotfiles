# ─── 30-abbr.fish — équivalent du bloc `alias` de config.nu ──────────────────
#
# Deux mécanismes en fish, contre un seul en nu :
#   • abbr  → s'expanse dans la ligne de commande quand tu tapes espace/entrée.
#             L'historique contient la commande réelle. Idéal pour les raccourcis
#             git (tu peux ajouter des flags après l'expansion).
#   • alias → crée une vraie fonction wrapper. Nécessaire quand la commande doit
#             rester opaque (ou pour renommer un binaire).
#
# Les fonctions plus complexes vivent dans ../functions/*.fish (autoload).

# ─── Fichiers / navigation ───────────────────────────────────────────────────
# ⚠️ En nu, `ls`/`ll` utilisaient le builtin nushell (`ls --all` valide).
#    En fish, `ls` = /bin/ls (BSD) qui ne connaît pas `--all`. On passe par eza.
alias l 'eza --all --icons'
alias ll 'eza --long --icons --git'
alias lt 'eza --tree --level=2 --long --icons --git'
alias lts 'eza --tree --level=2 --icons --git'
alias c 'clear'
alias v 'nvim'
alias b 'bat'

# ─── Git ─────────────────────────────────────────────────────────────────────
# Le `--` sépare les options d'abbr du nom + de l'expansion : indispensable
# dès que l'expansion contient des flags (--force, -a, ...).
abbr -a -- lg lazygit
abbr -a -- gc git commit -m
abbr -a -- gca git commit -a -m
abbr -a -- gp git push origin HEAD
abbr -a -- gpf git push origin HEAD --force
abbr -a -- gpsf git push origin HEAD --force-with-lease
abbr -a -- gpu git pull origin
abbr -a -- gst git status
abbr -a -- gdiff git diff
abbr -a -- gs git switch
abbr -a -- gb git branch
abbr -a -- gba git branch -a
abbr -a -- gadd git add
abbr -a -- ga git add -p
abbr -a -- gcoall git checkout -- .
abbr -a -- gr git remote
abbr -a -- gre git reset
abbr -a -- pu git pull
abbr -a -- glog "git log --graph --topo-order --pretty='%w(100,0,6)%C(yellow)%h%C(bold)%C(black)%d %C(cyan)%ar %C(green)%an%n%C(bold)%C(white)%s %N' --abbrev-commit"
