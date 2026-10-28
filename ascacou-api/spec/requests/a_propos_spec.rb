require "rails_helper"

RSpec.describe "/api/v1/a_propos", type: :request do
  it "répond sans id ni jeton : version du logiciel, droits, parties en cours" do
    create(:playing_room)
    create(:room)

    get "/api/v1/a_propos"

    expect(response).to have_http_status(:ok)
    expect(body["data"]).to include("type" => "a_propos", "id" => "ascacou")
    expect(body.dig("data", "attributes")).to include(
      "version" => Rails.root.join("VERSION").read.strip,
      "game_website" => "https://www.ascacou.com/",
      "games_playing" => 1
    )
  end
end
