require "rails_helper"

# Les annonces partent après le commit de chaque commande.
RSpec.describe "Annonces sur le cable" do
  let(:room) { create(:playing_room) }
  let(:game) { room.current_game }

  it "annonce chaque coup avec la nouvelle version de la partie" do
    expect { game.play!(game.first_player, coord: "3x3", color: "black") }
      .to have_broadcasted_to(room).from_channel(RoomChannel)
      .with(hash_including(type: "game", game: hash_including(id: game.id, version: game.lock_version + 1)))
  end

  it "annonce le salon quand une partie se termine (son score change)" do
    expect { game.resign!(game.first_player) }
      .to have_broadcasted_to(room).from_channel(RoomChannel).with(hash_including(type: "room"))
  end

  it "n'annonce pas le salon pour un coup qui ne termine pas la partie" do
    expect { game.play!(game.first_player, coord: "3x3", color: "black") }
      .not_to have_broadcasted_to(room).from_channel(RoomChannel).with(hash_including(type: "room"))
  end

  it "n'annonce rien quand une commande est refusée" do
    refused_move = lambda do
      game.play!(game.second_player, coord: "3x3", color: "black")
    rescue CommandRefused
      nil
    end
    expect(&refused_move).not_to have_broadcasted_to(room).from_channel(RoomChannel)
  end

  it "annonce l'arrivée de l'invité au salon et au salon d'accueil" do
    room = create(:room, visibility: "public")
    expect { room.join!(create(:user)) }
      .to have_broadcasted_to(room).from_channel(RoomChannel).with(hash_including(type: "room"))
      .and have_broadcasted_to(LobbyChannel::STREAM).with(hash_including(type: "room", id: room.code))
  end

  it "n'annonce pas un salon privé en attente au salon d'accueil" do
    expect { create(:room, visibility: "private") }.not_to have_broadcasted_to(LobbyChannel::STREAM)
  end
end
