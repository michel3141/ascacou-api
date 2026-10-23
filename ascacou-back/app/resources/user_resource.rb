class UserResource < ApplicationResource
  self.description = "Joueur anonyme. POST /users le crée et renvoie son jeton (JWT) dans l'en-tête X-JWT."

  attribute :name, :string, writable: true,
    description: "Nom affiché, 30 caractères max. Un joueur ne modifie que lui-même."

  # Création libre (joueur anonyme) ; un joueur ne modifie que lui-même.
  def save(user, meta = nil)
    if user.persisted? && user != current_user
      user.errors.add(:base, :forbidden)
      return user
    end
    super
  end
end
