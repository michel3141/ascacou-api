# Workflow de release : la version est calculée au moment de la release d'après
# les types de commits depuis le dernier tag (voir bin/bump).
#
#   make check            rubocop + rspec (dont compatibilité du schéma), dans le conteneur
#   make schema           met à jour doc/schema.json depuis le serveur de dev
#   make version          version publiée, position git, prochaine version
#
#   make prepare-release  arbre propre, quelque chose à publier, vérifications
#   make build            check, VERSION calculée, brouillon du CHANGELOG régénéré,
#                         image Docker (autant de fois que nécessaire)
#   (relire le CHANGELOG après le dernier build)
#   make release          commit « chore(release) » + tag ; rien n'est poussé pour l'instant
#
# Avant le tag, on peut corriger le code : par des commits, puis make build à nouveau
# (la version et le CHANGELOG suivent). Invariant : le commit tagué est exactement
# celui qui a été construit dans l'image.
# Si la validation de la release échoue : corriger (commits fix:), puis reprendre
# à prepare-release. Un tag publié n'est jamais réutilisé.

APP := ascacou-back
IMAGE := ascacou-back
STATE := .release-state
RELEASE_FILES := $(APP)/VERSION $(APP)/CHANGELOG.md
DOCKER ?= docker

# Évalué à chaque usage (pas :=) : la version change pendant prepare-release.
version = $(shell bin/bump V)

# Commande dans le conteneur backend (mise doit y être activé).
run = $(DOCKER) compose exec -T backend bash -lc 'eval "$$(~/.local/bin/mise activate bash)" && $(1)'

.PHONY: check schema version prepare-release build release \
  check-clean check-release-files check-version check-changelog

check:
	$(call run,bin/ci)

schema:
	curl -sf localhost:3000/api/v1/vandal/schema.json -o $(APP)/doc/schema.json.tmp
	python3 -m json.tool --no-ensure-ascii $(APP)/doc/schema.json.tmp > $(APP)/doc/schema.json
	rm -f $(APP)/doc/schema.json.tmp

version:
	@bin/bump version

check-clean:
	@test -z "$$(git status --porcelain)" || { \
		git status --short; echo "L'arbre de travail doit être propre"; exit 1; }

# Pas de modification non commitée en dehors de VERSION et CHANGELOG.md : sinon
# l'image contiendrait du code absent du tag. Les corrections se commitent.
check-release-files:
	@test -z "$$(git status --porcelain -- . $(addprefix ':!',$(RELEASE_FILES)))" || { \
		git status --short; \
		echo "Modifications non commitées : commiter les corrections (hors $(RELEASE_FILES))"; \
		exit 1; }

# VERSION doit être celle que build a calculée (pas de retouche à la main).
check-version:
	@test "$$(bin/bump V)" = "$$(bin/bump peek)" || { \
		echo "La version calculée est $$(bin/bump peek), VERSION dit $$(bin/bump V) : make build"; \
		exit 1; }

check-changelog:
	@grep -q "^# $(version)$$" $(APP)/CHANGELOG.md || { \
		echo "Pas d'entrée $(version) dans $(APP)/CHANGELOG.md"; exit 1; }

prepare-release: check-clean
	@echo "Prochaine version : $$(bin/bump peek)"
	$(MAKE) --no-print-directory check
	@echo prepared > $(STATE)
	@echo "Prêt : make build"

# La recette est développée avant de s'exécuter : la version écrite par
# bin/bump next se lit donc par le shell ($$(bin/bump V)), pas par $(version).
build: check-release-files
	@grep -qE '^(prepared|built)' $(STATE) 2>/dev/null || { \
		echo "Lancer d'abord make prepare-release"; exit 1; }
	$(MAKE) --no-print-directory check
	bin/bump next
	bin/bump write-changelog
	$(DOCKER) build -t $(IMAGE):$$(bin/bump V) -t $(IMAGE):latest $(APP)
	@echo "built $$(git rev-parse HEAD)" > $(STATE)
	@echo "Image $$(bin/bump V) construite. Après le dernier build : relire $(APP)/CHANGELOG.md, puis make release"

release: check-release-files check-version check-changelog
	@test "$$(cat $(STATE) 2>/dev/null)" = "built $$(git rev-parse HEAD)" || { \
		echo "Le dernier build ne correspond pas au commit courant : make build"; exit 1; }
	@# Une release sans commit est une anomalie : pas de || true.
	git add $(RELEASE_FILES)
	git commit -m "chore(release): $(version)"
	git tag -a "v$(version)" -m "chore(release): v$(version)"
	@echo released > $(STATE)
	@echo "v$(version) taguée localement. Rien n'a été poussé (git, image)."
