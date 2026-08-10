# ─── 10-secrets.fish — équivalent de secrets.nu ──────────────────────────────
#
# Aucune valeur en clair ici : tout vient du Keychain macOS.
#
# Ajouter un secret manuellement :
#   security add-generic-password -a $USER -s "MON_SECRET" -w "la_valeur" -U
#
# Voir un secret stocké :
#   security find-generic-password -a $USER -s "MON_SECRET" -w
# ─────────────────────────────────────────────────────────────────────────────

# Dans conf.d → chargé aussi dans les shells non-interactifs, donc les vars
# sont disponibles pour tous les process enfants (serveurs backend, etc.),
# exactement comme env.nu aujourd'hui.

function __keychain_get -a service -d "Lire un secret depuis le Keychain macOS"
    security find-generic-password -a $USER -s $service -w 2>/dev/null | string trim
end

# ─── Liste des secrets à exporter ────────────────────────────────────────────
#   JIRA_API_TOKEN     — Atlassian (vertuoza.atlassian.net)
#   ANTHROPIC_API_KEY  — omp
#   SOPS_AGE_KEY       — sops (casadana .env.encrypted)
for __secret in JIRA_API_TOKEN ANTHROPIC_API_KEY SOPS_AGE_KEY
    set -l __value (__keychain_get $__secret)
    if test -n "$__value"
        set -gx $__secret $__value
    end
end
set -e __secret __value
