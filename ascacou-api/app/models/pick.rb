# Une carte piochée pendant la distribution « pioche ».
class Pick < ApplicationRecord
  belongs_to :game, inverse_of: :picks

  validates :rank, numericality: { only_integer: true, greater_than: 0 }
  validates :card, inclusion: { in: Ascacou::Deal::CARDS }
  validates :hand, inclusion: { in: Game::ROLES }
end
