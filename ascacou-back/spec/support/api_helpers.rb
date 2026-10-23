module ApiHelpers
  # En-tête tel que l'envoie spraypaint (jwtStorage).
  def auth(user)
    { "Authorization" => %(Token token="#{AuthToken.issue(user)}") }
  end

  def body
    JSON.parse(response.body)
  end

  def error_codes
    body.fetch("errors").map { |error| error.dig("meta", "code") }
  end
end

RSpec.configure do |config|
  config.include ApiHelpers, type: :request
end
