require "rails_helper"

RSpec.describe RoomChannel, type: :channel do
  let(:room) { create(:playing_room) }
  let(:host) { room.host }
  let(:spectator) { create(:user) }

  it "refuse un salon inconnu" do
    stub_connection current_user: host
    subscribe(code: "inconnu")
    expect(subscription).to be_rejected
  end

  it "envoie l'état courant à l'abonnement, pour se resynchroniser" do
    stub_connection current_user: host
    subscribe(code: room.code)
    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_for(room)

    sync = transmissions.first
    expect(sync["type"]).to eq("sync")
    expect(sync["present"]).to eq([ host.id ])
    expect(sync.dig("room", "status")).to eq("playing")
    expect(sync.dig("game", "version")).to eq(room.current_game.lock_version)
  end

  it "accepte un spectateur anonyme : compté, sans présence nommée" do
    stub_connection current_user: nil
    expect { subscribe(code: room.code) }
      .to have_broadcasted_to(room).with(type: "viewers", count: 1)
    expect(subscription).to be_confirmed
    expect(transmissions.first["viewers"]).to eq(1)
    expect(RoomPresence.count).to eq(0)

    expect { unsubscribe }.to have_broadcasted_to(room).with(type: "viewers", count: 0)
  end

  it "compte un utilisateur identifié qui n'est pas joueur comme spectateur" do
    stub_connection current_user: spectator
    expect { subscribe(code: room.code) }
      .to have_broadcasted_to(room).with(type: "viewers", count: 1)
    expect(RoomPresence.count).to eq(0)
  end

  it "ne compte plus un spectateur sans signe de vie" do
    stub_connection current_user: nil
    subscribe(code: room.code)
    travel(RoomPresence::ABSENCE_DELAY + 1.second) { expect(RoomViewer.count_for(room)).to eq(0) }
  end

  it "tient la présence à jour : abonnement, ping, départ" do
    stub_connection current_user: host
    expect { subscribe(code: room.code) }
      .to have_broadcasted_to(room).with(type: "presence", user_id: host.id, present: true)
    expect(RoomPresence.present_user_ids(room)).to eq([ host.id ])

    travel RoomPresence::ABSENCE_DELAY + 1.second do
      expect(RoomPresence.absent?(room, host)).to be(true)
      perform :ping
      expect(RoomPresence.absent?(room, host)).to be(false)
    end

    expect { unsubscribe }
      .to have_broadcasted_to(room).with(type: "presence", user_id: host.id, present: false)
  end

  it "relaie les messages prédéfinis des joueurs seulement" do
    stub_connection current_user: host
    subscribe(code: room.code)
    expect { perform :say, message: "well_played" }
      .to have_broadcasted_to(room).with(type: "message", user_id: host.id, message: "well_played")
    travel(RoomChannel::MESSAGE_INTERVAL + 1.second) do
      expect { perform :say, message: "texte libre" }.not_to have_broadcasted_to(room)
    end
  end

  it "limite la fréquence des messages" do
    stub_connection current_user: host
    subscribe(code: room.code)
    perform :say, message: "hello"
    expect { perform :say, message: "hello" }.not_to have_broadcasted_to(room)
    travel(RoomChannel::MESSAGE_INTERVAL + 1.second) do
      expect { perform :say, message: "hello" }.to have_broadcasted_to(room)
    end
  end

  it "ignore les messages d'un spectateur" do
    stub_connection current_user: spectator
    subscribe(code: room.code)
    expect { perform :say, message: "hello" }.not_to have_broadcasted_to(room)
  end
end
