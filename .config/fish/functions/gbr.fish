# nu: def gbr_safe [] + alias gbr = gbr_safe
# fish : plus besoin de l'indirection def/alias, la fonction porte le bon nom.
function gbr -d "Supprime toutes les branches locales sauf main, develop et la courante"
    set -l current (git branch --show-current)
    for branch in (git branch --format='%(refname:short)')
        contains -- $branch main develop $current; and continue
        git branch -D $branch
    end
end
