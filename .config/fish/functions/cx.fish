# nu: def --env cx [arg] { cd $arg; ls -l }
# fish : pas besoin de `--env`, une fonction change le cwd du shell courant.
#
# ⚠️ Écart volontaire : en nu, `cx` utilisait le builtin `cd` (l'alias cd=z était
# défini plus bas dans le fichier, donc hors de portée). En fish les fonctions
# sont résolues à l'appel, donc `cd` ici = zoxide. `cx foo` peut donc sauter vers
# une entrée de la base zoxide, pas seulement vers un chemin littéral.
# Pour revenir au comportement nu strict : remplacer `cd` par `builtin cd`.
function cx -d "cd dans un dossier puis liste son contenu"
    cd $argv[1]; or return
    eza --long --icons --git
end
