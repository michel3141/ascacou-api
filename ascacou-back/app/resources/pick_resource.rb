class PickResource < ApplicationResource
  self.description = "Carte piochée (distribution pioche). À tour de rôle, en commençant par le joueur " \
    "qui ne commence pas la partie, chacun place une carte libre dans l'un des deux jeux, jusqu'à 8 + 8."

  belongs_to :game, description: "Partie de la pioche."

  attribute :game_id, :integer, writable: :creating?, filterable: true, description: "Partie en cours de pioche."
  attribute :rank, :integer, sortable: true, description: "Numéro de la pioche (1 à 16)."
  attribute :card, :integer, writable: :creating?, description: "Carte-motif, de 0 à 15."
  attribute :hand, :string_enum, allow: Game::ROLES, writable: :creating?,
    description: "Jeu qui reçoit la carte : host ou guest."

  default_sort [ { rank: :asc } ]

  # POST /picks : piocher une carte et la placer dans un jeu.
  def save(pick, meta = nil)
    transition(pick) do
      game = pick.game or raise CommandRefused, :invalid_game
      game.pick!(current_user, card: pick.card, hand: pick.hand)
      game.picks.last
    end
  end
end
