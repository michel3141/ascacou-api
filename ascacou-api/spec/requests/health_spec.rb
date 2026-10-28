require "rails_helper"

RSpec.describe "/up", type: :request do
  it "répond 200, sans version en en-tête (elle est dans /api/v1/a_propos)" do
    get "/up"
    expect(response).to have_http_status(:ok)
    expect(response.headers).not_to have_key("X-Api-Version")
  end
end
