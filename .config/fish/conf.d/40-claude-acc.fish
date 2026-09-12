# ─── 40-claude-acc.fish — comptes Claude Code multiples ──────────────────────
# claude-code-accounts (`claude-acc`) n'écrit ses wrappers que pour zsh/bash :
# getShellConfigPath() dans bin/cli.js ne teste que $SHELL contre zsh/bash et
# renvoie null pour fish → aucun `claude-<compte>` n'est défini ici.
#
# On reproduit donc `claude-acc shell-init` nativement, sans spawner node au
# démarrage du shell. La convention est stable et vient de cmdList() : un compte
# = un dossier ~/.claude-<nom>. Un nouveau compte créé par `claude-acc add` est
# pris en compte au prochain shell, sans rien éditer ici.

if type -q claude-acc
    for dir in $HOME/.claude-*
        test -d $dir; or continue # exclut ~/.claude-acc.json (le fichier de conf)
        set -l name (string replace -- "$HOME/.claude-" '' $dir)

        function claude-$name --wraps claude \
            --inherit-variable name --inherit-variable dir \
            --description "claude — compte $name"
            claude-acc sync -q -a $name 2>/dev/null
            CLAUDE_CONFIG_DIR=$dir claude $argv
        end
    end
end
