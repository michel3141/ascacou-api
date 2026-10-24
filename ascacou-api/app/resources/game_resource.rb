class GameResource < ApplicationResource
  self.description = "Partie d'un salon. POST /games { room_id } lance la partie suivante. " \
    "Chaque PATCH modifie un seul attribut, qui désigne l'action (voir chaque attribut). " \
    "Les champs calculés (board, legal_moves…) sont en lecture seule."

  belongs_to :room, description: "Salon de la partie."
  belongs_to :first_player, resource: UserResource, description: "Joueur qui commence."
  has_many :moves, description: "Coups, dans l'ordre."
  has_many :picks, description: "Cartes piochées (distribution pioche), dans l'ordre."

  # Création (partie suivante) : seulement le salon.
  attribute :room_id, :integer, readable: false, writable: :creating?,
    description: "Code du salon, pour lancer la partie suivante (la précédente doit être terminée)."
  attribute :number, :integer, description: "Rang de la partie dans le salon (1, 2, …)."
  attribute :status, :string_enum, allow: Game.statuses.keys,
    description: "drafting (pioche), playing ou finished."
  attribute :host_hand, :array_of_integers, description: "Cartes-motifs (0 à 15) de l'hôte."
  attribute :guest_hand, :array_of_integers, description: "Cartes-motifs (0 à 15) de l'invité."
  attribute :first_player_id, :integer, writable: :updating?,
    description: "Joueur qui commence. PATCH avec l'id de l'adversaire : laisser la main (avant le 1er coup)."
  attribute :opening_color, :string, writable: :updating?,
    description: "Pion imposé : couleur du premier pion, choisie par le second joueur (black ou white)."
  attribute :takeback_requested, :boolean, writable: :updating?,
    description: "Demande d'annulation en cours. true : demander (après avoir joué) ; " \
      "false : refuser (adversaire). Accepter : DELETE /moves/:id."
  attribute :result, :string, writable: :updating?,
    description: "host, guest ou draw. PATCH avec le rôle de l'adversaire : abandonner ; " \
      "avec son propre rôle : réclamer la victoire (adversaire absent depuis 2 minutes)."
  attribute :end_reason, :string, description: "score, resign (abandon) ou claim (victoire réclamée)."
  attribute :lock_version, :integer, writable: :updating?,
    description: "Version de la partie. À renvoyer avec une modification : si elle est dépassée, 409."

  # État calculé par le serveur : le front affiche, il ne recalcule pas les règles.
  attribute :board, :string,
    description: "Plateau, rangées séparées par / : b noir, w blanc, . vide (\"b..../...../..w../...../.....\")." do
    @object.board.to_s
  end

  attribute :current_player_id, :integer,
    description: "Joueur qui doit agir : piocher, choisir la couleur d'ouverture ou jouer." do
    @object.current_player&.id
  end

  attribute :awaiting_opening_color, :boolean,
    description: "Pion imposé : le second joueur doit choisir la couleur du premier pion." do
    @object.awaiting_opening_color?
  end

  attribute :required_color, :string,
    description: "Couleur imposée au prochain coup, ou null si le choix est libre." do
    @object.required_color
  end

  attribute :score, :hash, description: "Motifs reproduits de chaque jeu : { host, guest }." do
    @object.score
  end

  attribute :blocked_coords, :array_of_strings,
    description: "Cases où aucune couleur n'est jouable (« pions verts »)." do
    @object.blocked_coords
  end

  attribute :legal_moves, :hash,
    description: "Cases jouables et couleurs permises : { \"1x1\": [\"black\", \"white\"], … }." do
    next {} unless @object.playing?

    required = @object.required_color
    @object.board.legal_moves(multiple: @object.allow_multiple)
      .select { |_, color| required.nil? || color.to_s == required }
      .group_by(&:first).transform_values { |moves| moves.map { |_, color| color.to_s } }
  end

  filter :room_id, :integer

  # Chaque modification est une transition : l'attribut changé désigne l'action.
  TRANSITIONS = {
    "first_player_id" => ->(game, user, player_id) { game.pass_hand!(user, to: player_id) },
    "opening_color" => ->(game, user, color) { game.choose_opening_color!(user, color) },
    "takeback_requested" => ->(game, user, requested) {
      requested ? game.request_takeback!(user) : game.answer_takeback!(user, accept: false)
    },
    "result" => ->(game, user, result) {
      raise CommandRefused, :invalid_result unless Game::ROLES.include?(result)

      result == game.role_of(user) ? game.claim_victory!(user) : game.resign!(user)
    }
  }.freeze

  def base_scope
    Game.includes(:moves, :picks, room: %i[host guest])
  end

  def save(game, meta = nil)
    if game.new_record?
      return transition(game) { game.room.next_game!(current_user).current_game }
    end

    transition(game) do
      check_version!(game)
      attribute, value = single_change(game, ignore: "lock_version")
      TRANSITIONS.fetch(attribute) { raise CommandRefused, :not_writable }.call(game, current_user, value)
    end
  end

  private

  # lock_version envoyé par le client : s'il est dépassé, 409.
  def check_version!(game)
    return unless game.lock_version_changed?

    raise ActiveRecord::StaleObjectError.new(game, "update")
  end
end
