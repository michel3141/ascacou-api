class AProposController < ApplicationController
  def show
    render jsonapi: AProposResource.find(params)
  end
end
