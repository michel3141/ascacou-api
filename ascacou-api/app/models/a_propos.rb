# À propos de l'API (ressource singleton, sans table) : version du logiciel, droits,
# et le nombre de parties en cours, calculé à la lecture.
#
# Écartés le 2026-10-28 : salons en attente et joueurs présents. Les salons privés
# sont des invitations (seuls les publics compteraient), et la présence n'est connue
# que des joueurs dans un salon (ni spectateurs ni visiteurs de l'accueil) : des
# chiffres partiels, qui diraient autre chose que ce qu'ils ont l'air de dire.
class APropos
  ID = "ascacou"
  GAME_RIGHTS = "Ascacou (règles, nom, cartes motifs et charte graphique) © Marc Buonomo"
  CODE_RIGHTS = "Application © 2026 michel3141. Tous droits réservés."
  GAME_WEBSITE = "https://www.ascacou.com/"

  def id = ID
  def version = AscacouApi::VERSION
  def game_rights = GAME_RIGHTS
  def code_rights = CODE_RIGHTS
  def game_website = GAME_WEBSITE

  def games_playing
    Game.playing.count
  end
end
