# Spectateur d'un salon (abonnement au cable, identifié ou non), compté mais pas
# nommé. Une clé par abonnement : plusieurs onglets comptent plusieurs fois.
# Comme pour la présence des joueurs, un spectateur sans signe de vie depuis
# RoomPresence::ABSENCE_DELAY n'est plus compté (plantage, coupure sans adieu).
class RoomViewer < ApplicationRecord
  belongs_to :room

  def self.seen!(room, key, at: Time.current)
    upsert({ room_id: room.id, key:, last_seen_at: at }, unique_by: :key)
  end

  def self.leave!(key)
    where(key:).delete_all
  end

  def self.count_for(room, now: Time.current)
    where(room:).where(last_seen_at: (now - RoomPresence::ABSENCE_DELAY)..).count
  end
end
