# Joueur anonyme : son identité est un JWT signé contenant son id.
class User < ApplicationRecord
  has_many :hosted_rooms, class_name: "Room", foreign_key: :host_id, inverse_of: :host, dependent: :restrict_with_error
  has_many :joined_rooms, class_name: "Room", foreign_key: :guest_id, inverse_of: :guest, dependent: :restrict_with_error

  validates :name, presence: true, length: { maximum: 30 }
end
