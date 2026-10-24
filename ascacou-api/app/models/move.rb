class Move < ApplicationRecord
  belongs_to :game, inverse_of: :moves

  validates :rank, numericality: { only_integer: true, greater_than: 0 }
  validates :coord, inclusion: { in: Ascacou::Board::COORDS }
  validates :color, inclusion: { in: Game::COLORS }
  validates :next_color, inclusion: { in: Game::COLORS }, allow_nil: true
end
