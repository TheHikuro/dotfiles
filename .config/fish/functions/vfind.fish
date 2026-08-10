# nu: alias vfind = v (fzf --preview="bat --color=always {}")
# fish : ça doit être une fonction — un alias évaluerait fzf au chargement.
function vfind -d "Sélectionne un fichier via fzf et l'ouvre dans nvim"
    set -l file (fzf --preview 'bat --color=always {}')
    test -n "$file"; and nvim $file
end
