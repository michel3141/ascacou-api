require "rails_helper"

RSpec.describe "/up", type: :request do
  it "répond 200 avec la version du logiciel en en-tête" do
    get "/up"
    expect(response).to have_http_status(:ok)
    expect(response.headers["X-Api-Version"]).to eq(Rails.root.join("VERSION").read.strip)
  end
end
