require "rails_helper"

RSpec.describe "Sign out", type: :request do
  let(:user) { create(:user) }
  let(:session_and_token) { UserSession.start_for(user) }
  let(:user_session) { session_and_token.first }
  let(:raw_token) { session_and_token.second }

  it "revokes the current session and clears the refresh cookie" do
    cookies[:refresh_token] = raw_token

    delete "/api/v1/auth/sign_out"

    expect(response).to have_http_status(:no_content)
    expect(user_session.reload.revoked_at).to be_present
    expect(response.cookies["refresh_token"]).to be_blank
  end

  it "is safe without a refresh cookie" do
    expect { delete "/api/v1/auth/sign_out" }.not_to change(UserSession, :count)

    expect(response).to have_http_status(:no_content)
    expect(response.cookies["refresh_token"]).to be_blank
  end

  it "rejects the access token after signing out" do
    token = AccessToken.issue(user:, user_session:)
    cookies[:refresh_token] = raw_token

    delete "/api/v1/auth/sign_out"
    get "/api/v1/me", headers: { "Authorization" => "Bearer #{token}" }

    expect(response).to have_http_status(:unauthorized)
    expect(response.parsed_body.dig("error", "code")).to eq("invalid_token")
  end
end
