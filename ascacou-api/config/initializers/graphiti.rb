# Schéma de référence de l'API, commité dans doc/ (et non servi par public/) :
# il est récupéré du serveur de dev par curl, jamais généré (voir doc/api.md).
Graphiti.config.schema_path = Rails.root.join("doc/schema.json")

# Ressource singleton (GET /a_propos, sans id) : pour show, Graphiti cherche la route
# <chemin>/1 et ne la trouve pas, l'endpoint manquerait au schéma. Repli : le chemin
# seul, s'il mène à une action show.
Rails.application.config.after_initialize do
  default = Graphiti.config.context_for_endpoint
  singleton_show = lambda do |path|
    route = Rails.application.routes.recognize_path(path, method: :GET)
    "#{route[:controller]}_controller".classify.safe_constantize if route[:action] == "show"
  rescue ActionController::RoutingError
    nil
  end
  Graphiti.config.context_for_endpoint = lambda do |path, action|
    default.call(path, action) || (singleton_show.call(path) if action == :show)
  end
end
