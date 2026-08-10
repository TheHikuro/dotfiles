function env-encrypt -d "Chiffre un fichier .env vers .env.encrypted (sops)"
    set -l file $argv[1]
    if test -z "$file"
        echo "usage: env-encrypt <file>" >&2
        return 1
    end
    sops -e --input-type dotenv --output-type dotenv $file >.env.encrypted; or return
    echo "Encrypted $file -> .env.encrypted"
end
