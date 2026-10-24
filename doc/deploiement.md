# Déploiement du back

Conteneur Docker de l'app Rails (`ascacou-api/Dockerfile`, base `ruby:<version>-alpine`) :
Puma sert l'API et ActionCable (`/cable`). TLS (HTTPS / WSS) assuré par **Caddy**
devant le conteneur.
Image : `docker.lespyjamasrouges.fr/ascacou/api` (tags `<version>` et `latest`),
construite par `make build` et poussée par `make release` (voir `WORKFLOW.md`).

## Fronts servis

Un seul back (`RAILS_ENV=production`), utilisé par tous les fronts :

| Front                  | Origine                                   |
|------------------------|-------------------------------------------|
| web                    | `https://ascacou.lespyjamasrouges.fr`     |
| web, pré-prod          | `https://dev-ascacou.lespyjamasrouges.fr` |
| app Capacitor, iOS     | `capacitor://localhost`                   |
| app Capacitor, Android | `https://localhost`                       |

La pré-prod est celle du front : elle joue sur le même back, donc avec les mêmes
données que la production.

## Variables d'environnement

| Variable                        | Rôle                                  | Valeur                          |
|---------------------------------|---------------------------------------|---------------------------------|
| `RAILS_MASTER_KEY`              | déchiffre les credentials (1)         | `config/master.key`, hors dépôt |
| `DB_HOST`                       | serveur PostgreSQL                    |                                 |
| `ASCACOU_API_DATABASE_PASSWORD` | mot de passe de `ascacou_api`         |                                 |
| `CORS_ORIGINS`                  | origines de l'API et du cable (2)     | voir ci-dessous                 |
| `BASE_URL`                      | URL publique de l'API (3)             | à fixer                         |
| `RAILS_MAX_THREADS`             | threads Puma par processus (4)        | 3 par défaut                    |
| `WEB_CONCURRENCY`               | processus Puma, pour monter en charge | 1 par défaut                    |

- (1) `config/credentials.yml.enc` contient `secret_key_base`, qui signe aussi les JWT.
- (2) Séparées par des virgules. **Sans cette variable, toutes les origines sont acceptées.**
- (3) Pour les liens générés par Graphiti ; dépend du domaine de l'API (voir « À décider »).
- (4) Pool de connexions par processus : threads + 9 (4 workers ActionCable, 4 threads de
  sideloads Graphiti, 1 de marge). Au-delà de 3 ou 4 threads, le verrou global de Ruby
  (GVL) n'apporte plus de débit : on ajoute plutôt des processus.

`CORS_ORIGINS` : les origines de tous les fronts ci-dessus.

```
https://ascacou.lespyjamasrouges.fr,https://dev-ascacou.lespyjamasrouges.fr,capacitor://localhost,https://localhost
```

`capacitor://localhost` (iOS) et `https://localhost` (Android) sont les origines par
défaut d'une app Capacitor.

## Bases de données

Convention Rails 8 : **quatre bases** PostgreSQL, toutes avec l'utilisateur `ascacou_api`.

| Base                           | Usage                                              |
|--------------------------------|----------------------------------------------------|
| `ascacou_api_production`       | données du jeu                                     |
| `ascacou_api_production_cable` | Solid Cable (messages ActionCable entre processus) |
| `ascacou_api_production_cache` | Solid Cache (inutilisé pour l'instant)             |
| `ascacou_api_production_queue` | Solid Queue (inutilisé pour l'instant)             |

`bin/rails db:prepare` (lancé par `bin/docker-entrypoint` au démarrage du serveur)
les crée si l'utilisateur en a le droit, puis charge les schémas et applique les
migrations.

## À décider

- **Domaine de l'API** (`BASE_URL`) : sous-domaine dédié, ou même domaine que le front
  avec Caddy qui route `/api` et `/cable` vers le conteneur (le front web est alors de
  même origine ; `CORS_ORIGINS` reste nécessaire pour l'app Capacitor).
