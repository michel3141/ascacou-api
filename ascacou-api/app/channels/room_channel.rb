# Canal d'un salon, pour les joueurs comme pour les spectateurs.
#
# Le serveur annonce ce qui a changé, avec la version ; le client recharge par
# l'API JSON:API quand la version reçue dépasse la sienne. Le canal ne modifie
# rien, sauf la présence ; les messages prédéfinis ne sont pas stockés.
#
# Messages émis (champ type) :
#   sync      à chaque (re)connexion : état courant, pour se resynchroniser
#   room      le salon a changé (invité, statut, partie suivante)
#   game      la partie a changé ; version = lock_version
#   presence  signe de vie (ou départ) d'un joueur
#   viewers   nombre de spectateurs
#   message   message prédéfini d'un joueur
class RoomChannel < ApplicationCable::Channel
  # Codes des messages prédéfinis ; le texte (et la langue) vient du front.
  MESSAGES = %w[hello good_game thinking well_played oops wow thanks bye].freeze
  # Au plus un message par intervalle et par abonnement ; les autres sont ignorés.
  MESSAGE_INTERVAL = 3.seconds

  def subscribed
    @room = Room.find_by(code: params[:code])
    return reject unless @room

    stream_for @room
    @viewer_key = SecureRandom.uuid unless @room.player?(current_user)
    seen
    transmit self.class.sync_event(@room)
  end

  def unsubscribed
    return unless @room

    if @viewer_key
      RoomViewer.leave!(@viewer_key)
      broadcast_viewers
    else
      self.class.broadcast_to(@room, presence_event(present: false))
    end
  end

  # Appelé par le client à intervalle régulier (30 s). Sans signe de vie depuis
  # RoomPresence::ABSENCE_DELAY, un joueur est absent : son adversaire peut
  # réclamer la victoire. Un spectateur qui a rejoint le salon depuis son abonnement
  # devient joueur.
  def ping
    promote_viewer if @viewer_key && @room.reload.player?(current_user)
    seen
  end

  # Message prédéfini, par un joueur du salon. Les codes sont traduits par le front.
  def say(data)
    message = data["message"]
    return unless @room.player?(current_user) && MESSAGES.include?(message)
    return if @last_message_at && @last_message_at > MESSAGE_INTERVAL.ago

    @last_message_at = Time.current
    self.class.broadcast_to(@room, { type: "message", user_id: current_user.id, message: })
  end

  class << self
    def sync_event(room)
      game = room.current_game
      { type: "sync", room: room_payload(room), game: game && game_payload(game),
        present: RoomPresence.present_user_ids(room), viewers: RoomViewer.count_for(room) }
    end

    def room_changed(room)
      broadcast_to(room, { type: "room", room: room_payload(room) })
    end

    def game_changed(game)
      broadcast_to(game.room, { type: "game", game: game_payload(game) })
    end

    private

    def room_payload(room)
      { id: room.code, status: room.status, guest_id: room.guest_id, games_count: room.games.size }
    end

    def game_payload(game)
      { id: game.id, number: game.number, status: game.status, version: game.lock_version }
    end
  end

  private

  # Joueur : présence nommée. Autre abonné (spectateur, identifié ou non) : compté.
  # Le nombre n'est annoncé qu'à l'arrivée et au départ d'un spectateur.
  def seen
    if @viewer_key
      new_viewer = !RoomViewer.exists?(key: @viewer_key)
      RoomViewer.seen!(@room, @viewer_key)
      broadcast_viewers if new_viewer
    else
      RoomPresence.seen!(@room, current_user)
      self.class.broadcast_to(@room, presence_event(present: true))
    end
  end

  # Le spectateur ne l'est plus : il quitte les spectateurs, sa présence sera nommée.
  def promote_viewer
    RoomViewer.leave!(@viewer_key)
    @viewer_key = nil
    broadcast_viewers
  end

  def broadcast_viewers
    self.class.broadcast_to(@room, { type: "viewers", count: RoomViewer.count_for(@room) })
  end

  def presence_event(present:)
    { type: "presence", user_id: current_user.id, present: }
  end
end
