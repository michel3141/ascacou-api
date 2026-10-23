class MoveResource < ApplicationResource
  self.description = "Coup joué. POST /moves : jouer. DELETE /moves/:id : accepter la demande " \
    "d'annulation de ce coup (le dernier)."

  belongs_to :game, description: "Partie du coup."

  attribute :game_id, :integer, writable: :creating?, filterable: true, description: "Partie où jouer le coup."
  attribute :rank, :integer, writable: :creating?, sortable: true,
    description: "Numéro du coup (1, 2, …). S'il est envoyé et n'est pas le prochain : refus stale."
  attribute :coord, :string, writable: :creating?, description: "Case \"LxC\", ligne et colonne de 1 à 5."
  attribute :color, :string, writable: :creating?, description: "black ou white."
  attribute :next_color, :string, writable: :creating?,
    description: "Pion imposé : couleur imposée à l'adversaire (obligatoire sauf si le coup termine la partie)."

  default_sort [ { rank: :asc } ]

  # POST /moves : jouer un coup.
  def save(move, meta = nil)
    transition(move) do
      game = move.game or raise CommandRefused, :invalid_game
      game.play!(current_user, coord: move.coord, color: move.color,
                               next_color: move.next_color, rank: move.rank)
      game.moves.last
    end
  end

  # DELETE /moves/:id : accepter la demande d'annulation de ce coup.
  def delete(move, meta = nil)
    transition(move) do
      move.game.answer_takeback!(current_user, accept: true, move:)
      move
    end
  end
end
