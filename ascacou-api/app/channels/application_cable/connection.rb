module ApplicationCable
  # Le jeton (JWT) passe dans l'URL (/cable?token=…) : un navigateur ne peut pas
  # ajouter d'en-tête à une connexion WebSocket. Sans jeton : spectateur anonyme.
  # Un jeton invalide ou expiré est refusé, pour que le client le renouvelle.
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      token = request.params[:token]
      return if token.blank?

      payload = AuthToken.decode(token)
      self.current_user = payload && User.find_by(id: payload["sub"])
      reject_unauthorized_connection unless current_user
    end
  end
end
