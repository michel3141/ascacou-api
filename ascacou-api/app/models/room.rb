# Salon : deux joueurs, des réglages fixes et une suite de parties dont le score
# se cumule (1 la victoire, ½ la nulle, 0 la défaite) jusqu'à la fermeture.
class Room < ApplicationRecord
  include Refusable

  belongs_to :host, class_name: "User", inverse_of: :hosted_rooms
  belongs_to :guest, class_name: "User", inverse_of: :joined_rooms, optional: true
  has_many :games, -> { order(:number) }, dependent: :destroy, inverse_of: :room
  has_many :presences, class_name: "RoomPresence", dependent: :delete_all
  has_many :viewers, class_name: "RoomViewer", dependent: :delete_all

  enum :visibility, { public: "public", private: "private" }, prefix: true, validate: true
  enum :status, { waiting: "waiting", playing: "playing", closed: "closed" }, validate: true
  enum :deal_method, Ascacou::Deal::METHODS.index_with(&:to_s), prefix: :deal, validate: true

  scope :with_player, ->(user) { where(host: user).or(where(guest: user)) }

  before_validation(on: :create) { self.code ||= Ascacou::RoomCode.generate { |code| !Room.exists?(code:) } }
  validates :code, presence: true, uniqueness: true
  validate :guest_is_not_host

  after_commit do
    RoomChannel.room_changed(self)
    LobbyChannel.room_changed(self)
  end

  def code_label
    Ascacou::RoomCode.label(code)
  end

  def players
    [ host, guest ].compact
  end

  def player?(user)
    user.present? && [ host_id, guest_id ].include?(user.id)
  end

  def role_of(user)
    if user&.id == host_id then "host"
    elsif user&.id == guest_id then "guest"
    end
  end

  def opponent_of(user)
    user.id == host_id ? guest : host
  end

  def current_game
    games.last
  end

  def score
    games.select(&:finished?).each_with_object({ "host" => 0r, "guest" => 0r }) do |game, score|
      game.points.each { |role, points| score[role] += points }
    end
  end

  def join!(user, random: Random)
    with_lock do
      refuse!(:room_not_waiting) unless waiting?
      refuse!(:already_in_room) if user.id == host_id

      update!(guest: user, status: :playing)
      start_game!(random:)
    end
    self
  end

  def next_game!(user, random: Random)
    with_lock do
      refuse!(:not_a_player) unless player?(user)
      refuse!(:room_not_playing) unless playing?
      refuse!(:game_in_progress) unless current_game&.finished?

      start_game!(random:)
    end
    self
  end

  # Fermer le salon pendant une partie revient à l'abandonner.
  def close!(user)
    with_lock do
      refuse!(:not_a_player) unless player?(user)
      refuse!(:room_closed) if closed?

      game = current_game
      game.resign!(user) if game && !game.finished?
      closed!
    end
    self
  end

  private

  # Après une partie impaire, la revanche : mêmes cartes, mains échangées,
  # l'autre joueur commence. Sinon, nouvelle distribution et tirage au sort.
  def start_game!(random:)
    previous = current_game
    attributes =
      if previous&.number&.odd?
        { host_hand: previous.guest_hand, guest_hand: previous.host_hand,
          first_player: previous.second_player, status: :playing }
      else
        first_hand, second_hand = Ascacou::Deal.call(deal_method, random:)
        { host_hand: first_hand, guest_hand: second_hand,
          first_player: players.sample(random:), status: deal_draft? ? :drafting : :playing }
      end
    games.create!(number: (previous&.number || 0) + 1, **attributes)
  end

  def guest_is_not_host
    errors.add(:guest, :invalid) if guest_id.present? && guest_id == host_id
  end
end
