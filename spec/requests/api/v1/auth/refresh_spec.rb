require "rails_helper"

RSpec.describe "Refresh session", type: :request do
  let(:user) { create(:user, :hr, email: "hr@demo.test") }
  let(:session_and_token) { UserSession.start_for(user) }
  let(:user_session) { session_and_token.first }
  let(:raw_token) { session_and_token.second }

  def refresh
    post "/api/v1/auth/refresh", as: :json
  end

  def use_refresh_cookie(token)
    cookies[:refresh_token] = token
  end

  def expect_invalid_refresh
    expect(response).to have_http_status(:unauthorized)
    expect(response.parsed_body).to eq(
      "error" => {
        "code" => "invalid_refresh_token",
        "message" => "Invalid refresh token",
        "details" => []
      }
    )
  end

  it "rotates the refresh token and returns a new access token" do
    use_refresh_cookie(raw_token)
    session = user_session
    previous_token = raw_token

    expect { refresh }.not_to change(UserSession, :count)

    expect(response).to have_http_status(:ok)
    data = response.parsed_body.fetch("data")
    expect(data["access_token"]).to be_present
    expect(data.dig("user", "role")).to eq(Role::HR)

    new_token = response.cookies["refresh_token"]
    expect(new_token).to be_present
    expect(new_token).not_to eq(previous_token)
    expect(UserSession.find_by_token(previous_token)).to be_nil
    expect(UserSession.find_by_token(new_token)).to eq(session)
    expect(AccessToken.decode(data["access_token"])).to include("sid" => session.id)
  end

  it "rejects a missing refresh cookie" do
    expect { refresh }.not_to change(UserSession, :count)

    expect_invalid_refresh
  end

  it "rejects an unknown refresh token" do
    use_refresh_cookie("not-a-token")

    expect { refresh }.not_to change(UserSession, :count)

    expect_invalid_refresh
  end

  it "rejects a revoked session" do
    use_refresh_cookie(raw_token)
    user_session.revoke!

    refresh

    expect_invalid_refresh
  end

  it "rejects an expired session" do
    use_refresh_cookie(raw_token)

    travel 61.seconds do
      refresh

      expect_invalid_refresh
    end
  end

  it "rejects a session for an inactive account and revokes it" do
    use_refresh_cookie(raw_token)
    user.update!(active: false)

    refresh

    expect_invalid_refresh
    expect(user_session.reload.revoked_at).to be_present
  end
end
