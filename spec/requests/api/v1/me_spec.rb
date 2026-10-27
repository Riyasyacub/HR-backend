require "rails_helper"

RSpec.describe "Current user", type: :request do
  let(:user) { create(:user, :hr, email: "hr@demo.test") }
  let(:user_session) { UserSession.start_for(user).first }
  let!(:token) { AccessToken.issue(user:, user_session:) }

  def get_me(access_token = token)
    get "/api/v1/me", headers: { "Authorization" => "Bearer #{access_token}" }
  end

  def expect_invalid_token
    expect(response).to have_http_status(:unauthorized)
    expect(response.parsed_body).to eq(
      "error" => {
        "code" => "invalid_token",
        "message" => "Invalid access token",
        "details" => []
      }
    )
  end

  it "returns the signed-in HR user" do
    get_me

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq(
      "data" => {
        "user" => {
          "id" => user.id,
          "name" => user.name,
          "email" => user.email,
          "country" => user.country,
          "role" => Role::HR,
          "employee_id" => nil,
          "is_manager" => false
        }
      }
    )
  end

  it "returns the linked employee id" do
    employee_user = create(:user, email: "priya@demo.test")
    employee = create(:employee, user: employee_user)

    get "/api/v1/me", headers: authentication_headers(employee_user)

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("data", "user", "employee_id")).to eq(employee.id)
  end

  it "returns is_manager true when user's employee has direct reports" do
    manager_user = create(:user, email: "arjun@demo.test")
    arjun = create(:employee, user: manager_user)
    create(:employee, manager: arjun)

    get "/api/v1/me", headers: authentication_headers(manager_user)

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("data", "user", "is_manager")).to be(true)
  end

  it "returns the employee role" do
    employee = create(:user, email: "priya@demo.test")
    employee_session = UserSession.start_for(employee).first
    employee_token = AccessToken.issue(user: employee, user_session: employee_session)

    get_me(employee_token)

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("data", "user", "role")).to eq(Role::STANDARD_EMPLOYEE)
  end

  it "rejects a missing or malformed Authorization header" do
    get "/api/v1/me"

    expect_invalid_token

    get "/api/v1/me", headers: { "Authorization" => "Token #{token}" }

    expect_invalid_token
  end

  it "rejects an invalid access token" do
    get_me("not-a-token")

    expect_invalid_token
  end

  it "rejects an expired access token" do
    travel 16.minutes do
      get_me

      expect_invalid_token
    end
  end

  it "rejects a token after the user's token version changes" do
    user.update!(token_version: user.token_version + 1)

    get_me

    expect_invalid_token
  end

  it "rejects a token whose session is revoked" do
    user_session.revoke!

    get_me

    expect_invalid_token
  end

  it "rejects a token after the session inactivity window" do
    travel 61.seconds do
      get_me

      expect_invalid_token
    end
  end

  it "rejects a token for an inactive user" do
    user.update!(active: false)

    get_me

    expect_invalid_token
  end

  it "rejects a token whose session belongs to another user" do
    other_user = create(:user)
    other_session = UserSession.start_for(other_user).first
    foreign_token = AccessToken.issue(user:, user_session: other_session)

    get_me(foreign_token)

    expect_invalid_token
  end

  it "extends the session on authenticated activity" do
    issued_at = Time.current

    get_me
    expect(response).to have_http_status(:ok)

    travel_to(issued_at + 30.seconds) do
      get_me
      expect(response).to have_http_status(:ok)
    end

    travel_to(issued_at + 70.seconds) do
      get_me
      expect(response).to have_http_status(:ok)
    end
  end
end
