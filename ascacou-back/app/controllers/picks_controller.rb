class PicksController < ApplicationController
  before_action :require_user!, except: %i[index show]

  def index
    picks = PickResource.all(params)
    render jsonapi: picks
  end

  def show
    pick = PickResource.find(params)
    render jsonapi: pick
  end

  def create
    pick = PickResource.build(params)

    if pick.save
      render jsonapi: pick, status: 201
    else
      render jsonapi_errors: pick
    end
  end
end
