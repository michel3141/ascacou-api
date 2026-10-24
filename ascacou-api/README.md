# ascacou-api

Back du jeu Ascacou à deux en ligne : Rails 8.1, Ruby 4, Graphiti (JSON:API), PostgreSQL,
ActionCable.

- [API](doc/api.md) : principes, identité, ressources, transitions et codes de refus.
- Règles du jeu : `lib/ascacou` (plateau, motifs, distributions), sans dépendance à Rails.
- Parties et salons : `app/models` (`Room`, `Game`), où chaque action est validée.

## Développement

Avec le `compose.yml` du dossier parent :

```sh
docker compose up -d          # lance bin/setup : dépendances, base, serveur sur :3000
# mise doit être activé dans le shell du conteneur
docker compose exec backend bash -lc 'eval "$(~/.local/bin/mise activate bash)" && bundle exec rspec'
docker compose exec backend bash -lc 'eval "$(~/.local/bin/mise activate bash)" && bin/rubocop'
```
