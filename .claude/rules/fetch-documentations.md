
# Doc à jour via ctx7

Ton training peut être périmé. Pour toute question sur une **techno externe**, récupère la doc à jour via le CLI `ctx7` — même si tu crois connaître. Préférer à la recherche web pour la doc de lib.

**Déclenche** : lib, framework, SDK, API, CLI, service cloud — syntaxe d'API, config, migration de version, debug spécifique à une lib, install, usage d'un outil CLI. Même pour une techno connue (React, Next.js, Tailwind…).

**Ne déclenche pas** : refactoring, script from scratch, debug de logique métier, revue de code, concept de prog général.

## Étapes

1. **Résoudre l'ID** : `bunx ctx7@latest library <nom> "<question complète>"` — nom officiel avec ponctuation ("Next.js" pas "nextjs", "Three.js" pas "threejs"). Sauter cette étape seulement si l'utilisateur fournit déjà un ID `/org/project`.
2. **Choisir le match** (format `/org/project`) : match exact du nom, pertinence de la description, nb de snippets, réputation source (High/Medium), score benchmark (plus haut = mieux). Résultat douteux → reformuler ou tester un nom alternatif.
3. **Récupérer la doc** : `bunx ctx7@latest docs <libraryId> "<question complète>"`. Version précise → `/org/project/version` (issu de l'étape 1).
4. **Répondre** à partir de la doc récupérée.

## Règles

- Query = **question complète** de l'utilisateur (précise > mot-clé vague).
- **Max 3 commandes** par question.
- Jamais de secret (clé API, mot de passe) dans une query.
- Erreur de quota → proposer `bunx ctx7@latest login` ou la var `CONTEXT7_API_KEY`. **Ne jamais** retomber en silence sur le training.
