# 0.3.0

2026-10-28 feat: ressource a_propos (singleton) à la place de l'en-tête X-Api-Version
           GET /api/v1/a_propos, sans jeton ni id (findSingle côté spraypaint) : version du
           logiciel, droits sur le jeu et sur l'application, site du jeu, parties en cours.
           /up redevient la route de santé de Rails, sans en-tête. Repli dans l'initialiseur
           Graphiti : sans lui, l'endpoint singleton manquerait au schéma.
           
2026-10-27 fix: le salon est annoncé quand une partie se termine (score en direct)
           Le score du salon se calcule sur ses parties terminées : la fin d'une partie ne
           sauvegardait pas le salon, seule la partie était annoncée et les clients gardaient
           l'ancien score. Les clients existants rechargent déjà le salon sur cette annonce.
           
2026-10-26 feat: en pioche, laisser piocher l'adversaire en premier ; plus de main laissée après une pioche
2026-10-26 docs: versions de l'API (contrat /api/v1, logiciel a_propos.version) et règle des ruptures
           En 0.x, rupture sur place dans /api/v1 ; à partir de 1.0.0 (première app sur
           les stores), une rupture ouvre /api/v2 et /api/v1 reste servi.
           
2026-10-26 docs: licence (tous droits réservés) et conditions de contribution
           Code publié pour consultation ; contributions sur autorisation écrite, sous
           licence perpétuelle et irrévocable au profit de l'auteur (CONTRIBUTING.md).
           Le jeu et sa charte graphique restent à leurs auteurs.
           

# 0.2.0

2026-10-25 fix: mots des codes de salon plus courants, un thème par mot (nature · animal · ciel)
2026-10-25 fix: pas de partie suivante sans l'adversaire (victoire réclamée à volonté)
2026-10-25 feat: filter[player]=me et tri par défaut des salons (du plus récent au plus ancien)
2026-10-25 feat: realized_squares, motifs réalisés et leur position
2026-10-25 feat: last_move, dernier pion posé
2026-10-24 fix: un spectateur devenu joueur est présent dès son ping
2026-10-24 docs: README d'accueil

# 0.1.0

2026-10-24 refactor: ascacou-back devient ascacou-api (dossier, module, bases, compose)
           - Dossier ascacou-api, module AscacouApi, bases et rôle ascacou_api_*,
             variable ASCACOU_API_DATABASE_PASSWORD, projet compose ascacou-api :
             aligné sur l'image docker.lespyjamasrouges.fr/ascacou/api.
           - Pool de connexions : threads Puma + 9 (workers ActionCable, sideloads
             Graphiti, marge) au lieu de + 5, trop juste sous charge.
           - Déploiement : 3 threads par défaut, WEB_CONCURRENCY pour monter en charge.
           
2026-10-24 docs: déploiement (fronts servis, variables, quatre bases)
           Un seul back pour tous les fronts : CORS_ORIGINS liste les deux domaines web
           (production et pré-prod du front) et les origines Capacitor.
           
2026-10-24 feat: synchronisation par ActionCable (annonces, resync, présence, spectateurs, messages prédéfinis)
           - Connexion authentifiée par le JWT dans l'URL ; spectateur anonyme sans jeton.
           - RoomChannel : sync à chaque (re)connexion, annonces room/game après commit
             (version = lock_version), présence des joueurs entretenue par ping, compteur
             de spectateurs, messages prédéfinis éphémères (joueurs seulement, au plus un
             toutes les 3 s) : hello, good_game, thinking, well_played, oops, wow, thanks, bye.
           - LobbyChannel : annonce les changements des salons listés.
           - Origines du cable alignées sur CORS_ORIGINS.
           
2026-10-24 feat: reconstruction du back d'Ascacou (Rails 8.1, Graphiti 2)
           - Règles du jeu en Ruby pur (lib/ascacou) : plateau, motifs, coups légaux,
             pions verts, fin de partie, distributions du livret, codes de salon en mots.
           - Salons et parties (app/models) : le serveur fait autorité, chaque action est
             validée sous verrou ; score cumulé, revanche, pioche, pion imposé,
             annulation façon lichess, abandon et victoire réclamée.
           - API JSON:API sans route d'action : chaque écriture est une transition
             validée par le domaine (422 avec meta.code, 409 sur version périmée).
           - Identité anonyme par JWT (X-JWT, expiration glissante), CORS.
           - Documentation : doc/api.md et descriptions du schéma Graphiti.
           

# 0.0.0
