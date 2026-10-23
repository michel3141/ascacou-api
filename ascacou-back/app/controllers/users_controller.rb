class UsersController < ApplicationController
  before_action :require_user!, only: :update

  def show
    user = UserResource.find(params)
    render jsonapi: user
  end

  # Crée un joueur anonyme et lui remet son jeton dans X-JWT.
  def create
    user = UserResource.build(params)

    if user.save
      response.set_header("X-JWT", AuthToken.issue(user.data))
      render jsonapi: user, status: 201
    else
      render jsonapi_errors: user
    end
  end

  def update
    user = UserResource.find(params)

    if user.update
      render jsonapi: user
    else
      render jsonapi_errors: user
    end
  end
end
