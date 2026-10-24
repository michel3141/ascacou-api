class RoomResource < ApplicationResource
  # L'id public d'un salon est son code en mots : il sert de lien de partage.
  public_id :code

  self.description = "Salon : deux joueurs, des réglages fixes et une suite de parties dont le score " \
    "se cumule. L'id est le code du salon (lien de partage). Un salon privé en attente n'est pas " \
    "listé, sauf pour ses joueurs. Rejoindre : PATCH { guest_id: <moi> }. Fermer : PATCH { status: \"closed\" }."

  belongs_to :host, resource: UserResource, description: "Joueur qui a ouvert le salon."
  belongs_to :guest, resource: UserResource, description: "Joueur qui a rejoint le salon."
  has_many :games, description: "Parties du salon, dans l'ordre."

  attribute :code_label, :string,
    description: "Code à afficher, avec accents : « chevelure · serpent · caméléon »."
  attribute :visibility, :string_enum, allow: Room.visibilities.keys, writable: :creating?, filterable: true,
    description: "public : listé dans le salon d'accueil ; private (par défaut) : accessible par son lien."
  attribute :deal_method, :string_enum, allow: Room.deal_methods.keys, writable: :creating?,
    description: "Distribution des cartes : random (par défaut), inverse, fifty, max, ou draft (pioche)."
  attribute :allow_multiple, :boolean, writable: :creating?,
    description: "Variante motif multiple : un motif peut apparaître plusieurs fois, un seul point."
  attribute :imposed_color, :boolean, writable: :creating?,
    description: "Variante pion imposé : l'adversaire choisit la couleur du pion à jouer."
  attribute :status, :string_enum, allow: Room.statuses.keys, writable: :updating?, filterable: true,
    description: "waiting, playing ou closed. PATCH \"closed\" ferme le salon (une partie en cours est perdue)."
  attribute :guest_id, :integer, writable: :updating?,
    description: "Invité. PATCH avec son propre id pour rejoindre un salon en attente."
  attribute :created_at, :datetime, sortable: true, description: "Ouverture du salon."

  attribute :score, :hash, description: "Score cumulé { host, guest } : 1 la victoire, ½ la nulle." do
    @object.score.transform_values(&:to_f)
  end

  # Du plus récent au plus ancien, sauf tri demandé.
  default_sort [ { created_at: :desc } ]

  filter :player, :string, single: true, only: [ :eq ],
    description: "me : les salons du joueur authentifié (hôte ou invité), privés en attente compris." do
    eq do |scope, value|
      value == "me" && current_user ? scope.merge(Room.with_player(current_user)) : scope.none
    end
  end

  TRANSITIONS = {
    "guest_id" => ->(room, user, guest_id) {
      raise CommandRefused, :invalid_player unless guest_id.to_s == user.id.to_s

      room.join!(user)
    },
    "status" => ->(room, user, status) {
      raise CommandRefused, :invalid_status unless status == "closed"

      room.close!(user)
    }
  }.freeze

  # Un salon privé en attente n'est pas listé : on ne le rejoint que par son lien. Ses
  # joueurs, eux, le voient dans la liste (filter[player]=me : « vos salons »).
  def base_scope
    return Room.all unless current_action == :index

    listed = Room.visibility_public.or(Room.where.not(status: :waiting))
    current_user ? listed.or(Room.with_player(current_user)) : listed
  end

  def save(room, meta = nil)
    if room.new_record?
      room.host = current_user
      return super
    end

    transition(room) do
      attribute, value = single_change(room)
      TRANSITIONS.fetch(attribute) { raise CommandRefused, :not_writable }.call(room, current_user, value)
    end
  end
end
