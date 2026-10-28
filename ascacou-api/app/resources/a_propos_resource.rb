class AProposResource < ApplicationResource
  self.description = "À propos (singleton, GET /a_propos sans id) : version du logiciel, droits, " \
                     "chiffres du moment."
  self.adapter = Graphiti::Adapters::Null
  self.model = APropos
  self.type = :a_propos
  primary_endpoint "/a_propos", [ :show ]
  # Un seul objet, sans table : rien à filtrer.
  self.attributes_filterable_by_default = false

  attribute :id, :string
  attribute :version, :string,
    description: "Version du logiciel (0.3.0…) : quelle image tourne. Diagnostic, pas compatibilité."
  attribute :game_rights, :string, description: "Droits sur le jeu."
  attribute :code_rights, :string, description: "Droits sur l'application."
  attribute :game_website, :string, description: "Site du jeu."
  attribute :games_playing, :integer, description: "Parties en cours."

  def base_scope
    {}
  end

  def resolve(_scope)
    [ APropos.new ]
  end
end
