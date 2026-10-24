# JWT signé identifiant un joueur anonyme.
#
# Le front (spraypaint jwtStorage) le stocke et l'envoie dans
# `Authorization: Token token="…"`. Le serveur le renvoie dans l'en-tête X-JWT
# à la création du joueur, puis quand il vieillit : l'expiration est glissante.
module AuthToken
  ALGORITHM = "HS256".freeze
  LIFETIME = 30.days
  RENEW_AFTER = 1.day

  module_function

  def issue(user, now: Time.current)
    JWT.encode({ sub: user.id.to_s, iat: now.to_i, exp: (now + LIFETIME).to_i }, secret, ALGORITHM)
  end

  # Charge utile du jeton, ou nil s'il est invalide ou expiré.
  def decode(token)
    JWT.decode(token, secret, true, algorithm: ALGORITHM).first
  rescue JWT::DecodeError
    nil
  end

  def renew?(payload, now: Time.current)
    Time.at(payload.fetch("iat")) < now - RENEW_AFTER
  end

  def secret
    Rails.application.secret_key_base
  end
end
