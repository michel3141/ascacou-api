# API Ascacou

API JSON:API servie par Graphiti, sous `/api/v1`, consommée par le front avec spraypaint.

## Schéma

- **En développement**, le serveur sert l'explorateur Vandal (`/api/v1/vandal`) et le schéma
  à jour, généré à chaque requête : `/api/v1/vandal/schema.json`. Le front peut le télécharger.
- **En production**, ni Vandal ni le schéma ne sont servis : le front embarque le schéma dans
  son build.
- **`doc/schema.json`** est le schéma de référence, commité. Il n'est pas généré : on le
  récupère du serveur de dev quand l'API change.

  ```sh
  make schema   # depuis back/ : curl du schéma de dev, indenté pour des diffs lisibles
  ```

  La spec `spec/schema_spec.rb` échoue si l'API courante n'est plus compatible avec lui
  (attribut supprimé, type changé…) : c'est le signal d'un commit `feat!`.

## Principes

**Le serveur fait autorité.** Les règles du jeu ne vivent qu'au serveur
(`lib/ascacou`, `app/models`). Le front construit des ressources ; le serveur valide
chaque écriture et refuse ce qui n'est pas permis.

**Pas de routes d'action.** Une action s'exprime en créant, modifiant ou supprimant une
ressource : c'est la *transition* entre l'ancien et le nouvel état qui désigne l'action.
Règle de frontière :

> Une action passe par l'API si son résultat est un état qui a un sens par lui-même et que
> le serveur peut valider en comparant l'avant et l'après. Sinon elle ne passe pas par HTTP :
> ce qui est éphémère (présence, messages prédéfinis) passe par ActionCable.
> Si une action résiste, on la transforme en nom (une nouvelle ressource) plutôt que
> d'ajouter une route.

Conséquences :

- un `PATCH` ne modifie **qu'un seul attribut** à la fois (sinon `one_change_at_a_time`) ;
- la valeur envoyée n'est jamais enregistrée telle quelle : le serveur applique la
  transition qu'elle désigne, après contrôle ;
- seuls les attributs listés comme modifiables ci-dessous sont acceptés en écriture ;
  tout autre attribut est rejeté par Graphiti (400) ;
- l'état qui se calcule (plateau, trait, score…) est exposé en lecture : le front affiche,
  il ne recalcule pas les règles.

## Identité

Les joueurs sont anonymes. L'identité est un **JWT** (HS256, signé avec `secret_key_base`)
qui contient l'id du joueur (`sub`).

- `POST /users` crée le joueur et renvoie son jeton dans l'en-tête **`X-JWT`**.
- Chaque requête l'envoie dans `Authorization: Token token="<jwt>"` (format de
  `jwtStorage` de spraypaint, qui stocke aussi le jeton reçu dans `X-JWT`).
- Expiration glissante : le jeton vit 30 jours ; après un jour, toute réponse renvoie un
  jeton neuf dans `X-JWT`.
- Les lectures sont publiques (spectateurs). Toute écriture sans jeton valide : **401**.

## Erreurs

| Statut | Quand | Contenu |
|---|---|---|
| 401 | écriture sans jeton valide | — |
| 400 | requête mal formée, attribut non modifiable | erreurs Graphiti |
| 404 | ressource introuvable | — |
| **409** | `lock_version` envoyé dépassé : quelqu'un a agi entre-temps | recharger la partie, puis rejouer si besoin |
| **422** | action refusée par les règles | `errors[].meta.code` = code de refus (voir la liste) |

Un 422 est rangé par spraypaint dans `model.errors` ; le front traduit `meta.code`.

## Ressources

Notation : **L** lecture, **C** modifiable à la création, **M** modifiable en mise à jour
(= transition).

### `users`

| Attribut | | |
|---|---|---|
| `name` | L C M | 30 caractères max. Un joueur ne modifie que lui-même (`forbidden`). |

Routes : `GET /users/:id`, `POST /users`, `PATCH /users/:id`.

### `rooms` — salons

Un salon réunit deux joueurs, des réglages fixes et une suite de parties dont le score se
cumule (1 la victoire, ½ la nulle, 0 la défaite) jusqu'à sa fermeture.

**L'id d'un salon est son code** en trois mots (`chevelure-serpent-cameleon`) : c'est lui
qui figure dans le lien de partage.

| Attribut | | |
|---|---|---|
| `id` | L | code du salon |
| `code_label` | L | forme affichée, avec accents : « chevelure · serpent · caméléon » |
| `visibility` | L C | `public` (listé) ou `private` (par défaut ; accessible par son lien) |
| `deal_method` | L C | `random` (par défaut), `inverse`, `fifty`, `max`, `draft` (pioche) |
| `allow_multiple` | L C | variante motif multiple |
| `imposed_color` | L C | variante pion imposé |
| `status` | L M | `waiting`, `playing`, `closed` |
| `guest_id` | L M | invité |
| `score` | L | `{ host, guest }`, cumulé sur les parties terminées |
| `created_at` | L | triable |

Relations : `host`, `guest` (users), `games`.

Liste (`GET /rooms`) : salons publics et salons en cours (pour les spectateurs). Un salon
**privé en attente n'est jamais listé** ; on y accède par `GET /rooms/:code`.
Filtres utiles : `filter[status]`, `filter[visibility]`.

| Action | Requête | Conditions |
|---|---|---|
| ouvrir | `POST /rooms` | l'hôte est le joueur authentifié |
| rejoindre | `PATCH /rooms/:code` `{ guest_id: <moi> }` | salon en attente, pas l'hôte ; lance la 1ʳᵉ partie |
| fermer | `PATCH /rooms/:code` `{ status: "closed" }` | être joueur ; une partie en cours est perdue par celui qui ferme |

### `games` — parties

| Attribut | | |
|---|---|---|
| `number` | L | rang dans le salon (1, 2, …) |
| `status` | L | `drafting` (pioche), `playing`, `finished` |
| `host_hand`, `guest_hand` | L | cartes-motifs (0 à 15) de chaque joueur |
| `first_player_id` | L M | qui commence |
| `opening_color` | L M | variante pion imposé : couleur du premier pion |
| `takeback_requested` | L M | demande d'annulation en cours |
| `result` | L M | `host`, `guest`, `draw` |
| `end_reason` | L | `score`, `resign`, `claim` |
| `lock_version` | L M | version de la partie ; l'envoyer avec une modification pour détecter un conflit (409) |
| `board` | L | plateau, une ligne par rangée : `b` noir, `w` blanc, `.` vide (`"b..../...../..w../...../....."`) |
| `current_player_id` | L | joueur qui doit agir (piocher, choisir la couleur d'ouverture ou jouer) |
| `awaiting_opening_color` | L | le second joueur doit choisir la couleur du premier pion |
| `required_color` | L | couleur imposée au prochain coup, ou `null` si le choix est libre |
| `legal_moves` | L | cases jouables et couleurs permises : `{ "1x1": ["black", "white"], … }` |
| `blocked_coords` | L | cases où aucune couleur n'est jouable (« pions verts ») |
| `score` | L | `{ host, guest }` : motifs reproduits de chaque jeu |
| `realized_patterns` | L | motifs (0 à 15) présents sur le plateau : une carte est reproduite si sa valeur y figure |

Relations : `room`, `first_player` (user), `moves`, `picks`. Filtre : `filter[room_id]`.

| Action | Requête | Conditions |
|---|---|---|
| partie suivante | `POST /games` `{ room_id: <code> }` | la précédente est terminée |
| laisser la main | `PATCH` `{ first_player_id: <adversaire> }` | être premier joueur, aucun coup joué |
| couleur d'ouverture | `PATCH` `{ opening_color }` | pion imposé, être le second joueur, avant le 1ᵉʳ coup |
| demander l'annulation | `PATCH` `{ takeback_requested: true }` | avoir joué le dernier coup |
| refuser l'annulation | `PATCH` `{ takeback_requested: false }` | demande en cours, être l'adversaire |
| abandonner | `PATCH` `{ result: <rôle de l'adversaire> }` | partie non terminée |
| réclamer la victoire | `PATCH` `{ result: <mon rôle> }` | adversaire absent depuis 2 minutes |

Enchaînement des parties d'un salon : après une partie impaire, la revanche (mêmes cartes,
mains échangées, l'autre joueur commence) ; après une partie paire, nouvelle distribution
et tirage au sort du premier joueur.

### `moves` — coups

| Attribut | | |
|---|---|---|
| `game_id` | L C | |
| `rank` | L C | numéro du coup (1, 2, …) ; s'il est envoyé et ne correspond pas au prochain coup : `stale` |
| `coord` | L C | `"LxC"`, ligne et colonne de 1 à 5 |
| `color` | L C | `black` ou `white` |
| `next_color` | L C | variante pion imposé : couleur imposée à l'adversaire (obligatoire sauf si le coup termine la partie) |

| Action | Requête | Conditions |
|---|---|---|
| jouer | `POST /moves` | être au trait, coup légal, couleur imposée respectée |
| accepter l'annulation | `DELETE /moves/:id` | demande en cours, dernier coup, être l'adversaire |

La partie se termine d'elle-même quand plus aucun nouveau motif ne peut être reproduit.

### `picks` — pioche

Distribution `draft` : à tour de rôle, en commençant par le joueur qui **ne** commence
**pas** la partie, chacun place une carte libre dans l'un des deux jeux, jusqu'à 8 + 8.
Pas d'annulation.

| Attribut | | |
|---|---|---|
| `game_id` | L C | |
| `rank` | L | |
| `card` | L C | 0 à 15 |
| `hand` | L C | `host` ou `guest` |

Action : `POST /picks`.

## Codes de refus (422, `meta.code`)

| Code | Signification |
|---|---|
| `not_a_player` | l'auteur n'est pas joueur de ce salon |
| `not_your_turn` | ce n'est pas à lui d'agir |
| `one_change_at_a_time` | un `PATCH` doit modifier un seul attribut |
| `not_writable` | attribut accepté par l'API mais sans transition associée |
| `forbidden` | modification du profil d'un autre joueur |
| `stale` | coup envoyé avec un `rank` périmé (double envoi, retard) |
| **Salons** | |
| `room_not_waiting` | le salon a déjà ses deux joueurs |
| `already_in_room` | l'hôte ne peut pas rejoindre son propre salon |
| `room_not_playing`, `room_closed` | salon pas en jeu, ou fermé |
| `game_in_progress` | partie suivante demandée avant la fin de la partie |
| `invalid_player`, `invalid_status` | valeur de transition non permise (inscrire un autre joueur, statut autre que `closed`) |
| **Parties** | |
| `not_playing`, `game_finished` | partie pas en phase de jeu, ou terminée |
| `game_started`, `not_first_player` | laisser la main après le 1ᵉʳ coup, ou sans être premier joueur |
| `awaiting_opening_color`, `not_awaiting_opening_color` | couleur d'ouverture à choisir d'abord, ou déjà choisie |
| `invalid_result` | `result` autre que `host` / `guest` |
| `opponent_present` | victoire réclamée alors que l'adversaire est là |
| **Coups** | |
| `invalid_game`, `invalid_coord`, `invalid_color` | valeurs inconnues |
| `illegal_move` | case occupée, ou motif qui apparaîtrait deux fois |
| `imposed_color` | couleur différente de la couleur imposée |
| `next_color_required` | variante pion imposé : couleur pour l'adversaire manquante |
| **Annulation** | |
| `not_last_mover` | seul celui qui vient de jouer peut demander |
| `takeback_pending`, `no_takeback_pending` | demande déjà en cours, ou aucune demande |
| `not_last_move` | `DELETE` d'un autre coup que le dernier |
| **Pioche** | |
| `not_drafting` | la pioche est terminée |
| `invalid_card`, `card_taken` | carte inconnue ou déjà placée |
| `invalid_hand`, `hand_full` | jeu inconnu, ou déjà 8 cartes |

## Synchronisation (ActionCable)

Le cable **annonce** ; il ne transporte pas l'état. Le client recharge par l'API
JSON:API quand une annonce lui apprend qu'il est en retard. Toutes les actions de jeu
passent par l'API (HTTP), jamais par le cable.

**Connexion** : `ws(s)://<hôte>/cable?token=<jwt>`. Un navigateur ne peut pas ajouter
d'en-tête à une connexion WebSocket, d'où le jeton dans l'URL (filtré des logs Rails).
Sans jeton : spectateur anonyme. Jeton invalide ou expiré : connexion refusée (le
client doit d'abord obtenir un jeton valide par l'API).

Origines acceptées : celles de `CORS_ORIGINS` (toutes si `*`, en développement).

### `RoomChannel` — `{ channel: "RoomChannel", code: <code du salon> }`

Pour les joueurs et les spectateurs. Les joueurs du salon ont une présence nommée ; tout
autre abonné, identifié ou non, est un spectateur : compté, pas nommé. Messages reçus
(champ `type`) :

| `type` | Quand | Contenu |
|---|---|---|
| `sync` | à chaque abonnement, donc à chaque (re)connexion | `room` (id, status, guest_id, games_count), `game` (id, number, status, `version`), `present` (ids des joueurs présents), `viewers` (nombre de spectateurs) |
| `room` | le salon a changé (invité, statut, partie suivante) | `room` |
| `game` | la partie a changé (coup, pioche, annulation, fin…) | `game`, dont `version` = `lock_version` |
| `presence` | signe de vie ou départ d'un joueur | `user_id`, `present` |
| `viewers` | arrivée ou départ d'un spectateur | `count` |
| `message` | message prédéfini d'un joueur | `user_id`, `message` (code) |

**Resynchronisation** : à la réception de `sync` (après une coupure réseau, une veille,
un rechargement), comparer `game.version` avec la version locale et recharger la partie
si elle est en retard, ou s'il s'agit d'une autre partie. Même règle pour chaque `game`.
Un message manqué pendant une coupure n'est donc jamais un problème : le `sync` de la
reconnexion le rattrape.

Actions (`perform`) :

| Action | Données | Rôle |
|---|---|---|
| `ping` | — | signe de vie, **toutes les 30 s**, joueurs **et spectateurs**. Sans signe de vie depuis 2 minutes, un joueur est absent (son adversaire peut réclamer la victoire) et un spectateur n'est plus compté. |
| `say` | `{ message }` | message prédéfini, joueurs seulement, au plus un toutes les 3 s. Codes : `hello` (Bonjour !), `good_game` (Bonne partie !), `thinking` (Je réfléchis…), `well_played` (Bien joué !), `oops` (Oups !), `wow` (Waouh !), `thanks` (Merci !), `bye` (À bientôt !). Les autres sont ignorés. Rien n'est stocké. |

### `LobbyChannel` — `{ channel: "LobbyChannel" }`

Salon d'accueil : annonce `{ type: "room", id, status }` quand un salon listé change
(public, ou en cours pour les spectateurs). Le client recharge `GET /rooms`. Un salon
privé en attente n'est jamais annoncé.
