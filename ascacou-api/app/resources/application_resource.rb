# All Resources should inherit from ApplicationResource.
class ApplicationResource < Graphiti::Resource
  abstract_class
  adapter :active_record
  # Or follow config/environments:
  #   base_url ActionDispatch::Http::URL.url_for(Rails.application.routes.default_url_options)
  base_url ENV.fetch("BASE_URL", "http://localhost:3000")
  endpoint_namespace "/api/v1"

  # Defaults every Resource inherits. See https://graphiti.dev/concepts/resources

  # Attributes
  # attributes_readable_by_default     true
  # Écriture fermée par défaut : chaque attribut accepté en écriture est déclaré
  # explicitement, et chaque écriture est une transition validée par le domaine.
  attributes_writable_by_default false
  attributes_sortable_by_default false
  # attributes_filterable_by_default   true          # à garder : l'id doit rester filtrable
  # attributes_schema_by_default       true
  # typecast_reads                     true

  # Relationships
  # relationships_readable_by_default  true
  relationships_writable_by_default false
  # relationship_placeholders          false         # render placeholders for relationships with no ids and no link
  # belongs_to_resource_ids_by_default :foreign_key  # :foreign_key, :always, or :never

  # Filters
  # filter_blanks_treated_as           :literal      # :literal, :null, or :rejected

  # Sorting
  # default_sort                       nil           # per resource, e.g. [{id: :desc}]

  # Pagination
  # page_default_size                  nil           # unset falls back to 20
  # page_max_size                      1_000
  # page_cursors                       false         # render cursors for pagination
  # page_links                         false         # true, false, or :on_demand

  # Endpoints
  # validate_requests                  true          # refuse requests to undeclared endpoints

  # Links
  # relationship_links                 true          # true, false, or :on_demand
  # validate_links                     true          # refuse to render links to unroutable endpoints

  def current_user
    context&.current_user
  end

  # Une écriture est une transition du domaine : un refus devient une erreur de
  # validation (422, meta.code = code du refus) au lieu d'une exception.
  def transition(model)
    yield
  rescue CommandRefused => e
    model.errors.add(:base, e.code)
    model
  end

  # L'unique attribut modifié par la requête et sa nouvelle valeur. Le modèle est
  # ensuite rechargé : la valeur envoyée n'est jamais enregistrée telle quelle,
  # c'est le domaine qui applique la transition (et il verrouille un modèle propre).
  def single_change(model, ignore: nil)
    changes = model.changes_to_save.except(*ignore)
    model.reload
    raise CommandRefused, :one_change_at_a_time unless changes.size == 1

    attribute, (_old, value) = changes.first
    [ attribute, value ]
  end

  # Garde d'écriture : attribut accepté seulement à la création.
  def creating?(model)
    model.new_record?
  end

  # Garde d'écriture : attribut accepté seulement en mise à jour.
  def updating?(model)
    model.persisted?
  end
end
