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
