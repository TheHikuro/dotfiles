# ─── config.fish — réglages interactifs ──────────────────────────────────────
# Sourcé APRÈS tous les conf.d/*.fish.
# Équivalent du bloc `$env.config = { ... }` de config.nu, version courte :
# la quasi-totalité des 500 lignes de keybindings de nu ne faisait que
# redéfinir les défauts de reedline. fish a déjà tout ça.

if status is-interactive
    # ─── show_banner: false ──────────────────────────────────────────────────
    set -g fish_greeting ''

    # ─── edit_mode: vi ───────────────────────────────────────────────────────
    fish_vi_key_bindings

    # ─── cursor_shape (nu: emacs/vi_insert = block, vi_normal = underscore) ──
    set -g fish_cursor_default block
    set -g fish_cursor_insert block
    set -g fish_cursor_replace_one underscore
    set -g fish_cursor_visual block

    # ─── history ─────────────────────────────────────────────────────────────
    # fish : historique partagé entre sessions par défaut, ~256k entrées,
    # stocké dans ~/.local/share/fish/fish_history. Rien à configurer.

    # ─── keybindings ─────────────────────────────────────────────────────────
    # Ce que fish fait déjà nativement, identique à ta conf nu :
    #   Tab            → completion (pager)
    #   Ctrl-R         → history pager            (nu: history_menu)
    #   → / Ctrl-F     → accepte l'autosuggestion (nu: historyhintcomplete)
    #   Alt-→ / Alt-F  → accepte un mot           (nu: historyhintwordcomplete)
    #   Alt-Backspace  → efface un mot            (nu: backspaceword)
    #   Ctrl-A / Ctrl-E, Ctrl-W, Ctrl-K, Ctrl-U, Ctrl-L, Ctrl-C, Ctrl-D → idem
    #
    # Les seuls écarts à corriger (syntaxe fish 4.x ; en fish 3.x c'est \co / \cq) :
    bind ctrl-o edit_command_buffer # nu: open_command_editor
    bind -M insert ctrl-o edit_command_buffer
    bind ctrl-q history-pager # nu: search_history (Ctrl-Q)
    bind -M insert ctrl-q history-pager
end

# peon-ping quick controls
function peon; bash /Users/loancleris/.claude/hooks/peon-ping/peon.sh $argv; end
