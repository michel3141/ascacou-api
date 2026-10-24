require "rails_helper"

# Parcours complet par l'API JSON:API, comme le ferait le front avec spraypaint.
RSpec.describe "API de jeu", type: :request do
  let(:host) { create(:user) }
  let(:guest) { create(:user) }

  def open_room(visibility: "private", **settings)
    jsonapi_post "/api/v1/rooms", { data: { type: "rooms",
      attributes: { visibility:, deal_method: "max", **settings } } }, headers: auth(host)
    expect(response.status).to eq(201), response.body
    body.dig("data", "id")
  end

  def join(code, user = guest)
    jsonapi_patch "/api/v1/rooms/#{code}", { data: { type: "rooms", id: code,
      attributes: { guest_id: user.id } } }, headers: auth(user)
  end

  def playing_game
    code = open_room
    join(code)
    Room.find_by!(code:).current_game
  end

  def play(game, user, coord, color, **extra)
    jsonapi_post "/api/v1/moves", { data: { type: "moves",
      attributes: { game_id: game.id, coord:, color:, **extra } } }, headers: auth(user)
  end

  def patch_game(game, user, attributes)
    jsonapi_patch "/api/v1/games/#{game.id}", { data: { type: "games", id: game.id.to_s, attributes: } },
                  headers: auth(user)
  end

  describe "joueurs" do
    it "crée un joueur anonyme et remet son jeton dans X-JWT" do
      jsonapi_post "/api/v1/users", { data: { type: "users", attributes: { name: "Ada" } } }
      expect(response.status).to eq(201)
      token = response.headers["X-JWT"]
      expect(AuthToken.decode(token)["sub"]).to eq(body.dig("data", "id"))
    end

    it "refuse une écriture sans jeton" do
      handle_request_exceptions do
        jsonapi_post "/api/v1/rooms", { data: { type: "rooms", attributes: { deal_method: "max" } } }
      end
      expect(response.status).to eq(401)
    end

    it "renouvelle un jeton qui vieillit" do
      old = AuthToken.issue(host, now: 2.days.ago)
      jsonapi_get "/api/v1/users/#{host.id}", headers: { "Authorization" => %(Token token="#{old}") }
      expect(response.headers["X-JWT"]).to be_present
      jsonapi_get "/api/v1/users/#{host.id}", headers: auth(host)
      expect(response.headers["X-JWT"]).to be_nil
    end

    it "ne modifie que soi-même" do
      jsonapi_patch "/api/v1/users/#{guest.id}", { data: { type: "users", id: guest.id.to_s,
        attributes: { name: "Pirate" } } }, headers: auth(host)
      expect(response.status).to eq(422)
      expect(error_codes).to eq([ "forbidden" ])
    end
  end

  describe "salons" do
    it "s'ouvrent, se rejoignent par leur code et lancent la partie" do
      code = open_room
      expect(code).to match(/\A[a-z]+-[a-z]+-[a-z]+\z/)
      join(code)
      expect(response.status).to eq(200), response.body
      room = Room.find_by!(code:)
      expect(room.guest).to eq(guest)
      expect(room.current_game).to be_playing

      jsonapi_get "/api/v1/rooms/#{code}", params: { include: "games,host,guest" }
      expect(body.dig("data", "attributes", "status")).to eq("playing")
      expect(body.fetch("included").map { |r| r["type"] }).to include("games", "users")
    end

    it "ne listent pas un salon privé en attente, mais le montrent par son code" do
      private_code = open_room
      public_code = open_room(visibility: "public")
      jsonapi_get "/api/v1/rooms"
      expect(body.fetch("data").map { |room| room["id"] }).to eq([ public_code ])
      jsonapi_get "/api/v1/rooms/#{private_code}"
      expect(response.status).to eq(200)
    end

    it "refusent qu'on y inscrive quelqu'un d'autre" do
      code = open_room
      jsonapi_patch "/api/v1/rooms/#{code}", { data: { type: "rooms", id: code,
        attributes: { guest_id: guest.id } } }, headers: auth(create(:user))
      expect(error_codes).to eq([ "invalid_player" ])
    end

    it "refusent de changer les réglages après la création" do
      code = open_room
      handle_request_exceptions do
        jsonapi_patch "/api/v1/rooms/#{code}", { data: { type: "rooms", id: code,
          attributes: { deal_method: "fifty" } } }, headers: auth(host)
      end
      expect(response.status).to eq(400)
    end
  end

  describe "parties" do
    let(:game) { playing_game }
    let(:first) { game.first_player }
    let(:second) { game.second_player }

    it "exposent l'état calculé" do
      jsonapi_get "/api/v1/games/#{game.id}", params: { include: "moves" }
      attributes = body.dig("data", "attributes")
      expect(attributes["board"]).to eq("...../...../...../...../.....")
      expect(attributes["current_player_id"]).to eq(first.id)
      expect(attributes["legal_moves"]["1x1"]).to eq(%w[black white])
      expect(attributes["score"]).to eq("host" => 0, "guest" => 0)
      expect(attributes["realized_squares"]).to eq([])
      expect(attributes["last_move"]).to be_nil
      expect(body.dig("data", "relationships", "room", "data", "id")).to eq(game.room.code)
    end

    it "exposent les motifs reproduits sur le plateau" do
      [ [ first, "1x1", "black" ], [ second, "1x2", "black" ],
        [ first, "2x1", "black" ], [ second, "2x2", "white" ] ].each.with_index(1) do |(user, coord, color), rank|
        play(game, user, coord, color, rank:)
        expect(response.status).to eq(201), response.body
      end
      jsonapi_get "/api/v1/games/#{game.id}"
      # HG HD BG BD = noir noir noir blanc => 0b0001
      expect(body.dig("data", "attributes", "realized_squares")).to eq([ { "pattern" => 1, "coord" => "1x1" } ])
      expect(body.dig("data", "attributes", "last_move"))
        .to eq("coord" => "2x2", "color" => "white", "rank" => 4)
    end

    it "se jouent par POST /moves et refusent un coup hors tour avec un code" do
      play(game, first, "3x3", "black", rank: 1)
      expect(response.status).to eq(201), response.body
      expect(body.dig("data", "attributes", "coord")).to eq("3x3")

      play(game, first, "1x1", "white")
      expect(response.status).to eq(422)
      expect(error_codes).to eq([ "not_your_turn" ])
      expect(game.reload.moves.size).to eq(1)
    end

    it "laissent la main par PATCH first_player_id" do
      patch_game(game, first, first_player_id: second.id)
      expect(response.status).to eq(200), response.body
      expect(body.dig("data", "attributes", "current_player_id")).to eq(second.id)
    end

    it "gèrent l'annulation : demande par PATCH, acceptation par DELETE du coup" do
      play(game, first, "3x3", "black")
      move_id = body.dig("data", "id")
      patch_game(game, first, takeback_requested: true)
      expect(body.dig("data", "attributes", "takeback_requested")).to be(true)

      jsonapi_delete "/api/v1/moves/#{move_id}", headers: auth(second)
      expect(response.status).to eq(200), response.body
      expect(game.reload.moves).to be_empty
      jsonapi_get "/api/v1/games/#{game.id}"
      expect(body.dig("data", "attributes", "last_move")).to be_nil
    end

    it "s'abandonnent en donnant le résultat à l'adversaire" do
      patch_game(game, first, result: game.room.role_of(second))
      expect(body.dig("data", "attributes", "status")).to eq("finished")
      expect(body.dig("data", "attributes", "end_reason")).to eq("resign")
    end

    it "refusent deux transitions à la fois" do
      patch_game(game, first, first_player_id: second.id, takeback_requested: true)
      expect(error_codes).to eq([ "one_change_at_a_time" ])
    end

    it "répondent 409 à une version périmée" do
      play(game, first, "3x3", "black")
      handle_request_exceptions do
        patch_game(game, first, takeback_requested: true, lock_version: 0)
      end
      expect(response.status).to eq(409)
      expect(game.reload.takeback_requested).to be(false)
    end

    it "enchaînent la partie suivante par POST /games" do
      patch_game(game, first, result: game.room.role_of(second))
      jsonapi_post "/api/v1/games", { data: { type: "games", attributes: { room_id: game.room.code } } },
                   headers: auth(first)
      expect(response.status).to eq(201), response.body
      expect(body.dig("data", "attributes", "number")).to eq(2)
    end
  end

  describe "pioche" do
    it "se joue par POST /picks" do
      code = open_room(deal_method: "draft")
      join(code)
      game = Room.find_by!(code:).current_game
      jsonapi_post "/api/v1/picks", { data: { type: "picks",
        attributes: { game_id: game.id, card: 5, hand: "guest" } } }, headers: auth(game.second_player)
      expect(response.status).to eq(201), response.body
      expect(game.reload.guest_hand).to eq([ 5 ])
    end
  end
end
