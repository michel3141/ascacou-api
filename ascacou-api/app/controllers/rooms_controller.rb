class RoomsController < ApplicationController
  before_action :require_user!, except: %i[index show]

  def index
    rooms = RoomResource.all(params)
    render jsonapi: rooms
  end

  def show
    room = RoomResource.find(params)
    render jsonapi: room
  end

  def create
    room = RoomResource.build(params)

    if room.save
      render jsonapi: room, status: 201
    else
      render jsonapi_errors: room
    end
  end

  def update
    room = RoomResource.find(params)

    if room.update
      render jsonapi: room
    else
      render jsonapi_errors: room
    end
  end
end
