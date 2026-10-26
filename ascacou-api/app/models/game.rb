# Une partie d'un salon. Le serveur fait autorité : chaque commande est validée
# sous verrou, et tout ce qui se déduit des coups (plateau, trait, score, pions
# verts, fin) est recalculé plutôt que stocké.
class Game < ApplicationRecord
  include Refusable

  COLORS = Ascacou::Board::COLORS.map(&:to_s).freeze
  ROLES = %w[host guest].freeze

  belongs_to :room, inverse_of: :games
  belongs_to :first_player, class_name: "User"
  has_many :moves, -> { order(:rank) }, dependent: :delete_all, inverse_of: :game
  has_many :picks, -> { order(:rank) }, dependent: :delete_all, inverse_of: :game

  enum :status, { drafting: "drafting", playing: "playing", finished: "finished" }, validate: true
  enum :result, { host: "host", guest: "guest", draw: "draw" }, prefix: :won_by, validate: { allow_nil: true }
  enum :end_reason, { score: "score", resign: "resign", claim: "claim" }, prefix: :ended_by, validate: { allow_nil: true }

  validates :number, numericality: { only_integer: true, greater_than: 0 }

  # Toute commande sauvegarde la partie (lock_version augmente) : une seule annonce
  # suffit, coups et pioches compris.
  after_commit { RoomChannel.game_changed(self) }
  validates :opening_color, inclusion: { in: COLORS }, allow_nil: true
  validate :first_player_is_a_player

  delegate :host, :guest, :allow_multiple, :imposed_color, :player?, :role_of, :opponent_of, to: :room

  # --- état calculé -----------------------------------------------------------

  def board
    Ascacou::Board.from_moves(moves.map { |move| [ move.coord, move.color ] })
  end

  def second_player
    opponent_of(first_player)
  end

  # Le joueur qui doit agir : piocher, choisir la couleur d'ouverture ou jouer.
  # À la pioche, c'est le second joueur qui commence, pour compenser.
  def current_player
    if finished? then nil
    elsif drafting? then picks.size.even? ? second_player : first_player
    elsif awaiting_opening_color? then second_player
    else moves.size.even? ? first_player : second_player
    end
  end

  def last_mover
    return if moves.empty?

    moves.size.odd? ? first_player : second_player
  end

  # Variante pion imposé : le second joueur choisit la couleur du premier pion.
  def awaiting_opening_color?
    playing? && imposed_color && moves.empty? && opening_color.nil?
  end

  # Couleur imposée au prochain coup, ou nil si le choix est libre (pas de
  # variante, ou plus aucune case jouable dans la couleur imposée).
  def required_color
    return unless playing? && imposed_color

    color = moves.empty? ? opening_color : moves.last.next_color
    return if color.nil?

    color if board.legal_moves(multiple: allow_multiple).any? { |_, legal_color| legal_color.to_s == color }
  end

  def hand_of(role)
    role.to_s == "host" ? host_hand : guest_hand
  end

  # Un point par motif reproduit pour celui qui le détient dans son jeu.
  def score
    realized = board.realized_patterns
    ROLES.index_with { |role| (hand_of(role) & realized).size }
  end

  def points
    case result
    when "draw" then ROLES.index_with { 1/2r }
    when *ROLES then ROLES.index_with { |role| role == result ? 1r : 0r }
    else ROLES.index_with { 0r }
    end
  end

  def blocked_coords
    allow_multiple ? [] : board.blocked_coords
  end

  # --- commandes ----------------------------------------------------------------

  # Pioche : place une carte libre dans le jeu de l'hôte ou de l'invité.
  def pick!(user, card:, hand:)
    command(user) do
      refuse!(:not_drafting) unless drafting?
      refuse!(:not_your_turn) unless current_player == user
      card = Integer(card, exception: false)
      refuse!(:invalid_card) unless Ascacou::Deal::CARDS.include?(card)
      refuse!(:card_taken) if (host_hand + guest_hand).include?(card)
      hand = hand.to_s
      refuse!(:invalid_hand) unless ROLES.include?(hand)
      refuse!(:hand_full) if hand_of(hand).size >= Ascacou::Deal::HAND_SIZE

      picks.create!(rank: picks.size + 1, card:, hand:)
      self["#{hand}_hand"] = (hand_of(hand) + [ card ]).sort
      self.status = :playing if host_hand.size + guest_hand.size == Ascacou::Deal::CARDS.size
    end
  end

  # « Laisser la main » : le joueur dont c'est le tour passe son tour, avant le premier
  # geste de la partie. to : le futur premier joueur, quand la demande l'exprime
  # (PATCH first_player_id).
  # - Pioche, avant la première carte : celui qui doit piocher laisse l'autre piocher en
  #   premier, et commencera donc la partie (to = lui-même). Après la pioche, la main
  #   ne se laisse plus : la compensation est faite.
  # - Autres distributions, avant le premier coup : le premier joueur laisse commencer
  #   l'adversaire (to = l'adversaire).
  def pass_hand!(user, to: nil)
    command(user) do
      if drafting?
        refuse!(:game_started) if picks.any?
        refuse!(:not_your_turn) unless current_player == user
        refuse!(:invalid_player) if to && to.to_s != user.id.to_s

        self.first_player = user
      else
        refuse!(:not_playing) unless playing?
        refuse!(:game_started) if moves.any? || picks.any?
        refuse!(:not_first_player) unless first_player == user
        refuse!(:invalid_player) if to && to.to_s != second_player.id.to_s

        self.first_player = second_player
        self.opening_color = nil
      end
    end
  end

  def choose_opening_color!(user, color)
    command(user) do
      refuse!(:not_awaiting_opening_color) unless awaiting_opening_color?
      refuse!(:not_your_turn) unless current_player == user
      refuse!(:invalid_color) unless COLORS.include?(color.to_s)

      self.opening_color = color.to_s
    end
  end

  # rank : numéro attendu du coup, pour rejeter un envoi en double ou périmé.
  # next_color : en variante pion imposé, la couleur imposée à l'adversaire.
  def play!(user, coord:, color:, next_color: nil, rank: nil)
    command(user) do
      refuse!(:not_playing) unless playing?
      refuse!(:awaiting_opening_color) if awaiting_opening_color?
      refuse!(:not_your_turn) unless current_player == user
      refuse!(:stale) if rank && rank.to_i != moves.size + 1
      coord, color = coord.to_s, color.to_s
      refuse!(:invalid_coord) unless Ascacou::Board::COORDS.include?(coord)
      refuse!(:invalid_color) unless COLORS.include?(color)
      required = required_color
      refuse!(:imposed_color) if required && color != required

      current = board
      refuse!(:illegal_move) unless current.legal?(coord, color, multiple: allow_multiple)

      over = current.place(coord, color).finished?(multiple: allow_multiple)
      next_color = imposed_color && !over ? next_color.to_s : nil
      refuse!(:next_color_required) if next_color && !COLORS.include?(next_color)

      moves.create!(rank: moves.size + 1, coord:, color:, next_color:)
      self.takeback_requested = false
      finish(:score) if over
    end
  end

  # Façon lichess : celui qui vient de jouer demande, l'adversaire répond.
  def request_takeback!(user)
    command(user) do
      refuse!(:not_playing) unless playing?
      refuse!(:not_last_mover) unless last_mover == user
      refuse!(:takeback_pending) if takeback_requested

      self.takeback_requested = true
    end
  end

  # move : le coup visé quand la demande l'exprime (DELETE /moves/:id).
  def answer_takeback!(user, accept:, move: nil)
    command(user) do
      refuse!(:no_takeback_pending) unless playing? && takeback_requested
      refuse!(:not_your_turn) unless current_player == user
      refuse!(:not_last_move) if move && move.id != moves.last.id

      moves.last.destroy! if accept
      self.takeback_requested = false
    end
  end

  def resign!(user)
    command(user) do
      refuse!(:game_finished) if finished?

      finish(:resign, winner: opponent_of(user))
    end
  end

  # Réclamer la victoire quand l'adversaire a disparu.
  def claim_victory!(user, now: Time.current)
    command(user) do
      refuse!(:game_finished) if finished?
      refuse!(:opponent_present) unless RoomPresence.absent?(room, opponent_of(user), now:)

      finish(:claim, winner: user)
    end
  end

  private

  # Toute commande passe par ici : verrou sur la partie (les associations sont
  # rechargées), contrôle du joueur, puis sauvegarde. lock_version sert de numéro
  # de version aux clients : il doit augmenter même si seul un coup a été ajouté.
  def command(user)
    with_lock do
      refuse!(:not_a_player) unless player?(user)
      yield
      self.updated_at = Time.current
      save!
    end
    self
  end

  def finish(reason, winner: nil)
    self.status = :finished
    self.end_reason = reason
    self.takeback_requested = false
    self.result =
      if winner then role_of(winner)
      else
        host_score, guest_score = score.values_at("host", "guest")
        if host_score > guest_score then "host"
        elsif guest_score > host_score then "guest"
        else "draw"
        end
      end
  end

  def first_player_is_a_player
    errors.add(:first_player, :invalid) unless player?(first_player)
  end
end
