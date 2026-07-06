#
# Pour ajouter un secret manuellement :
#   security add-generic-password -a $env.USER -s "MON_SECRET" -w "la_valeur"
#
# Pour voir les secrets stockés :
#   security find-generic-password -a $env.USER -s "MON_SECRET" -w
# ─────────────────────────────────────────────────────────────────────────────

def keychain-get [service: string] {
  try {
       security find-generic-password -a $env.user -s $service -w 
        | decode utf-8 
        | str trim
  } catch {
    ""
  }
}

# ─── Jira ────────────────────────────────────────────────────────────────────
let jira_token = (keychain-get "JIRA_API_TOKEN")
if ($jira_token | is-not-empty) {
  $env.JIRA_API_TOKEN = $jira_token
}

# ─── Anthropic (omp) ────────────────────────────────────────────────────────
let anthropic_api_key = (keychain-get "ANTHROPIC_API_KEY")
if ($anthropic_api_key | is-not-empty) {
  $env.ANTHROPIC_API_KEY = $anthropic_api_key
}

# ─── Ajouter d'autres secrets ici ─────────────────────────────────────────
# Exemple :
# let gh_token = (keychain-get "GITHUB_TOKEN")
# if ($gh_token | is-not-empty) {
#   $env.GITHUB_TOKEN = $gh_token
# }
