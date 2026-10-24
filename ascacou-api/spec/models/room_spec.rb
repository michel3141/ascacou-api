require "rails_helper"

RSpec.describe Room do
  let(:host) { create(:user) }
  let(:guest) { create(:user) }
  let(:room) { create(:room, host:, deal_method: "max") }

  def finish(game, winner: nil)
    game.resign!(winner ? game.opponent_of(winner) : game.first_player)
  end

  it "génère un code de partage en mots" do
    expect(room.code).to match(/\A[a-z]+-[a-z]+-[a-z]+\z/)
    expect(Ascacou::RoomCode.normalize(room.code_label)).to eq(room.code)
    expect(room).to be_waiting
    expect(room).to be_visibility_private
  end

  describe "#join!" do
    it "installe l'invité et lance la première partie" do
      room.join!(guest, random: Random.new(1))
      game = room.current_game
      expect(room).to be_playing
      expect(game.number).to eq(1)
      expect(game.host_hand).to eq(Ascacou::Deal::PREPARED[:max])
      expect(game.guest_hand).to eq(Ascacou::Deal::CARDS - Ascacou::Deal::PREPARED[:max])
      expect([ host, guest ]).to include(game.first_player)
    end

    it "refuse l'hôte lui-même et un salon déjà complet" do
      expect { room.join!(host) }.to raise_error(CommandRefused, "already_in_room")
      room.join!(guest)
      expect { room.join!(create(:user)) }.to raise_error(CommandRefused, "room_not_waiting")
    end

    it "commence par la pioche en distribution pioche" do
      room = create(:room, host:, deal_method: "draft")
      room.join!(guest)
      expect(room.current_game).to be_drafting
      expect(room.current_game.host_hand).to be_empty
    end
  end

  describe "#next_game!" do
    before { room.join!(guest, random: Random.new(1)) }

    it "refuse tant que la partie est en cours" do
      expect { room.next_game!(host) }.to raise_error(CommandRefused, "game_in_progress")
    end

    it "alterne revanche (mains échangées, l'autre commence) et nouvelle donne" do
      first = room.current_game
      finish(first)
      room.next_game!(guest)
      revenge = room.current_game
      expect(revenge.number).to eq(2)
      expect(revenge.host_hand).to eq(first.guest_hand)
      expect(revenge.guest_hand).to eq(first.host_hand)
      expect(revenge.first_player).to eq(first.second_player)

      finish(revenge)
      room.next_game!(host)
      third = room.current_game
      expect(third.number).to eq(3)
      expect(third.host_hand).to eq(first.host_hand)
    end

    it "refuse un spectateur" do
      finish(room.current_game)
      expect { room.next_game!(create(:user)) }.to raise_error(CommandRefused, "not_a_player")
    end
  end

  describe "#score" do
    it "cumule 1 par victoire et ½ par nulle" do
      room.join!(guest)
      finish(room.current_game, winner: host)
      room.next_game!(host)
      finish(room.current_game, winner: host)
      room.next_game!(host)
      room.current_game.update!(status: :finished, result: :draw, end_reason: :score)
      expect(room.reload.score).to eq("host" => 5/2r, "guest" => 1/2r)
    end
  end

  describe "#close!" do
    it "ferme le salon et fait perdre la partie en cours à celui qui part" do
      room.join!(guest)
      room.close!(guest)
      expect(room).to be_closed
      expect(room.current_game).to be_won_by_host
      expect(room.current_game).to be_ended_by_resign
    end

    it "permet à l'hôte de fermer un salon en attente" do
      room.close!(host)
      expect(room).to be_closed
    end
  end
end
