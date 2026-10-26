# Workflow de release (back)

La version n'est jamais choisie à l'avance : elle est **calculée à chaque build**
d'après les types de commits depuis le dernier tag (`bin/bump`). Une correction
ajoutée avant le tag peut donc la changer (un `feat` après des `fix`) : le build
suivant en tient compte, le CHANGELOG aussi.
Entre deux releases, `VERSION` indique la dernière version publiée ;
`make version` montre où en est le code et ce que serait la prochaine version.

```
                 ┌────────────────────────┐
                 │ développement          │
                 │ - commits typés        │
                 │ - make check           │
                 │ - make schema (si API) │
                 └───────────┬────────────┘
                             │
                             ▼
                 ┌────────────────────────┐
           ┌────▶│ prepare-release        │
           │     │ - arbre propre         │
           │     │ - quelque chose à      │
           │     │   publier ?            │
           │     │ - check                │
           │     └───────────┬────────────┘
           │                 │
           │                 ▼
           │     ┌────────────────────────┐
           │     │ build                  │◀──┐
           │     │ (0..n fois)            │   │ corriger avant le tag :
           │     │ - check                │   │ commits (fix:…), puis
           │     │ - VERSION calculée     │   │ build à nouveau
           │     │ - brouillon CHANGELOG  │   │
           │     │ - image :<version>     │   │
           │     │ - image :latest        │───┘
           │     └───────────┬────────────┘
           │                 │
           │                 ▼
           │       relire / retoucher le CHANGELOG
           │       (après le dernier build)
           │                 │
           │                 ▼
           │     ┌────────────────────────┐
           │     │ release (une fois)     │
           │     │ - commit chore(release)│
           │     │ - tag vX.Y.Z           │
           │     │ - push de l'image      │
           │     └───────────┬────────────┘
           │                 │
           │                 ▼
           │     ┌────────────────────────┐
           │     │ validation réelle      │
           │     │ (image, déploiement,   │
           │     │  recette)              │
           │     └──────┬──────────┬──────┘
           │            │          │
           │     échec  │          │ succès
           │            ▼          ▼
           │  ┌───────────────┐  ┌──────────────────┐
           │  │ corriger      │  │ rien à faire :   │
           └──│ (commits fix:)│  │ pas de bump après│
              └───────────────┘  │ la release       │
                                 └──────────────────┘
```

## Recettes, dans l'ordre

Toutes se lancent depuis `back/`.

1. **`make version`** — informatif : version publiée, position git, prochaine version.
2. **`make prepare-release`** — test que l'arbre est prêt pour une release
3. **`make build`** — autant de fois que nécessaire (tests de l'image) : calcule la version et build `docker.lespyjamasrouges.fr/ascacou/api:<version>` et `:latest`

   **Tant que rien n'est tagué, on peut corriger le code** : commiter les corrections,
   **sans** `VERSION` ni `CHANGELOG.md` (`git add <fichiers>`, pas `git commit -a`),
   puis relancer `make build`. Garde-fous :
   - `build` refuse une modification non commitée (hors `VERSION` et `CHANGELOG.md`) :
     l'image contiendrait du code absent du tag ;
   - `release` refuse si un commit a été ajouté depuis le dernier `build`.

4. **Relire `ascacou-api/CHANGELOG.md`**, une fois, **après le dernier build**, et le retoucher si besoin.
5. **`make release`** — une seule fois : commit, tag et push de l'image (le push git reste à la main)
6. **Validation réelle** de l'image publiée.

En cas de doute sur l'étape en cours : le fichier `.release-state` contient
`prepared`, `built <commit construit>` ou `released`.

## Version et CHANGELOG : seulement par la release

Entre un build et la release, la version et le CHANGELOG sont modifiés sans être
commités : ils appartiennent au commit `chore(release)`. Deux protections :

- le hook `.githooks/commit-msg`, activé par `make prepare-release`
  (`git config core.hooksPath .githooks`), refuse un commit qui les embarque
  (`git commit -a`…) sans être un `chore(release)` ; `--no-verify` pour passer outre ;
- `bin/bump guard`, lancé par `prepare-release` et `build`, rattrape un tel commit
  (hook non installé, `--no-verify`) et le nomme.

## Types de commits

Format : `<type>: <description en français>` (scope optionnel : `feat(api): …`).

| Type       | Pour                                            | Version                                             |
|------------|-------------------------------------------------|-----------------------------------------------------|
| `fix`      | correction de bug                               | patch (0.1.0 → 0.1.1)                               |
| `perf`     | performance                                     | patch                                               |
| `feat`     | nouvelle fonctionnalité                         | minor (0.1.0 → 0.2.0)                               |
| `feat!`    | changement cassant (ou pied `BREAKING CHANGE:`) | major (1.0.0 → 2.0.0), minor en 0.x (0.1.0 → 0.2.0) |
| `docs`     | documentation                                   | pas de release                                      |
| `refactor` | réorganisation sans changement de comportement  | pas de release                                      |
| `test`     | tests                                           | pas de release                                      |
| `chore`    | maintenance, outillage, release                 | pas de release                                      |
| `ci`       | intégration continue                            | pas de release                                      |

Le CHANGELOG reprend `feat`, `feat!`, `fix`, `perf`, `refactor` et `docs`.

**Changement cassant de l'API** : la spec `spec/schema_spec.rb` échoue quand l'API
n'est plus compatible avec `doc/schema.json`. Si c'est voulu : commit en `feat!`,
puis `make schema` pour mettre la référence à jour.
