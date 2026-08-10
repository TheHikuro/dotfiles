function env-decrypt -d "Déchiffre .env.encrypted vers un fichier .env (sops)"
    set -l file $argv[1]
    test -z "$file"; and set file .env
    sops -d --input-type dotenv --output-type dotenv .env.encrypted >$file; or return
    echo "Decrypted .env.encrypted -> $file"
end
