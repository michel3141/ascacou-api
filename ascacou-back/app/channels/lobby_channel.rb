# Salon d'accueil : annonce les changements des salons listés (publics, ou en cours
# pour les spectateurs). Le client recharge GET /rooms. Un salon privé en attente
# n'est jamais annoncé : on ne le trouve que par son lien.
class LobbyChannel < ApplicationCable::Channel
  STREAM = "lobby".freeze

  def subscribed
    stream_from STREAM
  end

  def self.room_changed(room)
    return unless room.visibility_public? || !room.waiting?

    ActionCable.server.broadcast(STREAM, { type: "room", id: room.code, status: room.status })
  end
end
