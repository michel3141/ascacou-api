class GamesController < ApplicationController
  before_action :require_user!, except: %i[index show]

  def index
    games = GameResource.all(params)
    render jsonapi: games
  end

  def show
    game = GameResource.find(params)
    render jsonapi: game
  end

  def create
    game = GameResource.build(params)

    if game.save
      render jsonapi: game, status: 201
    else
      render jsonapi_errors: game
    end
  end

  def update
    game = GameResource.find(params)

    if game.update
      render jsonapi: game
    else
      render jsonapi_errors: game
    end
  end
end
