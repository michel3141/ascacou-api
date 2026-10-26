# Déploiement du back

Conteneur Docker de l'app Rails (`ascacou-api/Dockerfile`, base `ruby:<version>-alpine`) :
Puma sert l'API et ActionCable (`/cable`). TLS (HTTPS / WSS) assuré par **Caddy**, sur
le routeur en amont : il joint l'API en HTTP par le réseau local, sur le port 3000 du
serveur.
Image : `docker.lespyjamasrouges.fr/ascacou/api` (tags `<version>` et `latest`),
construite par `make build` et poussée par `make release` (voir `WORKFLOW.md`).
Elle contient aussi `deploy/compose.yaml`, que `back/setup` en extrait pour l'installer
sur un serveur (voir « Installation et mise à jour »).

## Domaine

L'API a son propre domaine, **`ascacou-api.lespyjamasrouges.fr`** (défaut de `BASE_URL`
dans le compose) ; le front web a les siens. Le front appelle
`https://ascacou-api.lespyjamasrouges.fr/api/v1` et `wss://ascacou-api.lespyjamasrouges.fr/cable`.

Caddy, sur le routeur (le WebSocket du cable passe sans réglage particulier) :

```
ascacou-api.lespyjamasrouges.fr {
	reverse_proxy <ip locale du serveur>:3000
}
```

Entre Caddy et le serveur, le trafic est en clair (jetons compris) : réserver le port
3000 du serveur au routeur (pare-feu), ou n'écouter que sur l'interface du réseau local
(`compose.override.yaml`).

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

| Variable                        | Rôle                                  | Valeur                                    |
|---------------------------------|---------------------------------------|-------------------------------------------|
| `SECRET_KEY_BASE`               | signe les JWT (1)                     | `openssl rand -hex 64`                    |
| `DB_HOST`                       | serveur PostgreSQL                    |                                           |
| `ASCACOU_API_DATABASE_PASSWORD` | mot de passe de `ascacou_api`         |                                           |
| `CORS_ORIGINS`                  | origines de l'API et du cable (2)     | voir ci-dessous                           |
| `BASE_URL`                      | URL publique de l'API (3)             | `https://ascacou-api.lespyjamasrouges.fr` |
| `RAILS_MAX_THREADS`             | threads Puma par processus (4)        | 3 par défaut                              |
| `WEB_CONCURRENCY`               | processus Puma, pour monter en charge | 1 par défaut                              |

- (1) Générée sur le serveur, gardée avec les sauvegardes, **jamais changée** : la changer
  invalide tous les JWT (chaque joueur repart avec une nouvelle identité anonyme). Rails la
  lit avant les credentials : `config/master.key` ne sert pas en production.
- (2) Séparées par des virgules. **Sans cette variable, toutes les origines sont acceptées.**
- (3) Liens générés par Graphiti ; seul son domaine est accepté dans l'en-tête `Host`
  (403 sinon), hormis `/up`.
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

## Installation et mise à jour

Copier `back/setup` sur le serveur (dépendances : docker avec compose, jq, curl,
openssl), dans un dossier dédié (par exemple `/srv/ascacou-api`), puis :

```
docker login docker.lespyjamasrouges.fr
./setup install <tag>
```

- **`./setup install <tag>`** : refuse si `compose.yaml`, `.env` ou
  `compose.override.yaml` existe ; extrait le compose de l'image ; génère `.env`
  (secrets aléatoires, `chmod 600`) et `compose.override.yaml` (port de l'API) ;
  démarre et attend que l'API soit en bonne santé.
- **`./setup update <tag>`** : refuse si rien n'est installé ; extrait le compose de la
  version ; sauvegarde la base ; écrit la version dans `.env` ; démarre et attend.
- **`./setup backup`** : `pg_dump` de la base du jeu dans `backups/` (horodaté, avec la
  version).
- **`./setup status`** : version en service, état des conteneurs, dernières lignes du log.
- **`./setup versions`** : versions disponibles sur le registre, celle en service marquée
  d'une `*` (identifiants de `docker login`, lus dans `~/.docker/config.json`).

Toujours une version précise (`latest` est refusé) : `.env` indique ce qui tourne.
De l'extérieur, l'en-tête `X-Api-Version` de `/up` le dit aussi :
`curl -sI https://ascacou-api.lespyjamasrouges.fr/up | grep -i x-api-version`.

- **`compose.yaml` est remplacé à chaque `update`** : ne pas le modifier sur le serveur.
  Les réglages propres au serveur (ports, variables…) vont
  dans **`compose.override.yaml`** : `install` le crée avec le port de l'API et des
  exemples commentés, puis personne n'y touche. Docker compose le fusionne tout seul
  avec `compose.yaml` (résultat : `docker compose config`).
- **`.env` n'est jamais écrasé** : il contient `SECRET_KEY_BASE` et le mot de passe de la
  base. À sauvegarder avec `compose.override.yaml` et `backups/`.
- **`setup` n'est pas dans l'image** : il change rarement. Quand une version demande un
  script plus récent, `install` et `update` le refusent avant de rien modifier
  (« recopier back/setup »).
- **Revenir en arrière** : `./setup update <version précédente>`. Si la version annulée a
  migré la base, restaurer aussi la sauvegarde faite juste avant elle :

```
docker compose stop api
docker compose exec -T postgres pg_restore -U ascacou_api -d ascacou_api_production \
  --clean --if-exists < backups/<fichier>.dump
./setup update <version précédente>
```

### Contrat entre `setup` et `deploy/compose.yaml`

`back/setup` suppose, côté image :

- le compose à `/rails/deploy/compose.yaml` ;
- les services `api` et `postgres` ;
- la base `ascacou_api_production` et le rôle `ascacou_api` ;
- les variables de `.env` : `ASCACOU_API_IMAGE`, `ASCACOU_API_TAG`, `SECRET_KEY_BASE`,
  `ASCACOU_API_DATABASE_PASSWORD`.

Changer l'un de ces points, c'est changer le contrat : incrémenter `SETUP_VERSION`
dans `setup` **et** `x-setup` dans `deploy/compose.yaml`, puis le signaler dans le
CHANGELOG (« recopier back/setup »). Le compose déclare la version minimale du script
(1 si `x-setup` est absent) : un `setup` récent doit continuer à installer les versions
précédentes, sinon on ne peut plus revenir en arrière.

