# nu: def shrink-img [input, --max-kb, --out]
# Le portage le plus verbeux : nu avait `path parse`, `ls | get size`, `into int`,
# `math round`. En fish il faut passer par `string`, `stat` et `math`.
function shrink-img -d "Compresse une image jusqu'à une taille cible (KB)"
    argparse 'm/max-kb=' 'o/out=' -- $argv; or return

    set -l input $argv[1]
    if test -z "$input"
        echo "usage: shrink-img <image> [--max-kb 1000] [--out out.jpg]" >&2
        return 1
    end
    set -q _flag_max_kb; or set _flag_max_kb 1000

    set -l out $_flag_out
    if test -z "$out"
        set out (string replace -r '\.[^.]*$' '' -- (basename $input))_small.jpg
    end

    cp $input $out; or return

    set -l quality 90
    while true
        sips -s format jpeg -s formatOptions $quality $input --out $out >/dev/null; or return

        # `math` ne fait pas de comparaisons (contrairement à nu) : on arrondit
        # en entier et on compare avec `test`, qui ne gère pas les flottants.
        set -l bytes (stat -f%z $out)
        set -l size_kb (math -s0 "round($bytes / 1000)")

        echo "quality $quality -> $size_kb KB"

        if test $size_kb -le $_flag_max_kb; or test $quality -le 10
            break
        end
        set quality (math $quality - 10)
    end
    echo "Done: $out"
end
