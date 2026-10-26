# /up : santé de l'API (Rails::HealthController) et version du logiciel en en-tête,
# pour savoir de l'extérieur quelle image tourne : curl -sI …/up.
class HealthController < Rails::HealthController
  before_action { response.set_header("X-Api-Version", AscacouApi::VERSION) }
end
