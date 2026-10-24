class MovesController < ApplicationController
  before_action :require_user!, except: %i[index show]

  def index
    moves = MoveResource.all(params)
    render jsonapi: moves
  end

  def show
    move = MoveResource.find(params)
    render jsonapi: move
  end

  def create
    move = MoveResource.build(params)

    if move.save
      render jsonapi: move, status: 201
    else
      render jsonapi_errors: move
    end
  end

  def destroy
    move = MoveResource.find(params)

    if move.destroy
      render jsonapi: { meta: {} }, status: 200
    else
      render jsonapi_errors: move
    end
  end
end
