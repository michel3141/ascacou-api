require "rails_helper"

RSpec.describe ApplicationCable::Connection, type: :channel do
  let(:user) { create(:user) }

  it "identifie le joueur par le jeton de l'URL" do
    connect "/cable?token=#{AuthToken.issue(user)}"
    expect(connection.current_user).to eq(user)
  end

  it "accepte un spectateur anonyme" do
    connect "/cable"
    expect(connection.current_user).to be_nil
  end

  it "refuse un jeton invalide ou expiré" do
    expect { connect "/cable?token=faux" }.to have_rejected_connection
    expired = AuthToken.issue(user, now: (AuthToken::LIFETIME + 1.day).ago)
    expect { connect "/cable?token=#{expired}" }.to have_rejected_connection
  end
end
