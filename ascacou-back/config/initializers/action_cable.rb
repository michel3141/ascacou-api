# Mêmes origines que l'API (CORS_ORIGINS). "*" (par défaut, en développement) :
# pas de contrôle d'origine. En production, CORS_ORIGINS doit lister le front.
origins = ENV.fetch("CORS_ORIGINS", "*").split(",")

Rails.application.configure do
  if origins == [ "*" ]
    config.action_cable.disable_request_forgery_protection = true
  else
    config.action_cable.allowed_request_origins = origins
  end
end
