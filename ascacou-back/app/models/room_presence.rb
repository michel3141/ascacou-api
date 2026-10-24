# Dernier signe de vie d'un joueur ou d'un spectateur dans un salon.
class RoomPresence < ApplicationRecord
  ABSENCE_DELAY = 2.minutes

  belongs_to :room
  belongs_to :user

  def self.seen!(room, user, at: Time.current)
    upsert({ room_id: room.id, user_id: user.id, last_seen_at: at }, unique_by: %i[room_id user_id])
  end

  def self.present_user_ids(room, now: Time.current)
    where(room:).where(last_seen_at: (now - ABSENCE_DELAY)..).pluck(:user_id)
  end

  def self.absent?(room, user, now: Time.current)
    last_seen_at = where(room:, user:).pick(:last_seen_at)
    last_seen_at.nil? || last_seen_at < now - ABSENCE_DELAY
  end
end
