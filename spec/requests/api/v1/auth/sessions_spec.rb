require "rails_helper"

RSpec.describe "Sign in", type: :request do
  def sign_in(email:, password: "Demo@1234", headers: {})
    post "/api/v1/auth/sign_in", params: { email:, password: }, as: :json, headers:
  end

  def expect_generic_failure
    expect(response).to have_http_status(:unauthorized)
    expect(response.parsed_body).to eq(
      "error" => {
        "code" => "invalid_credentials",
        "message" => "Invalid email or password",
        "details" => []
      }
    )
    expect(response.cookies["refresh_token"]).to be_nil
  end

  it "signs in an HR user and sets an HttpOnly refresh cookie" do
    user = create(:user, :hr, email: "hr@demo.test")

    expect do
      sign_in(email: " HR@DEMO.TEST ", headers: { "Origin" => "http://localhost:5173" })
    end.to change(UserSession, :count).by(1)

    expect(response).to have_http_status(:ok)

    data = response.parsed_body.fetch("data")
    expect(data["access_token"]).to be_present
    expect(data["token_type"]).to eq("Bearer")
    expect(data["expires_in"]).to eq(15.minutes.to_i)
    expect(data["user"]).to include(
      "id" => user.id,
      "email" => "hr@demo.test",
      "role" => Role::HR,
      "country" => "India",
      "employee_id" => nil,
      "is_manager" => false
    )
    expect(response.parsed_body.to_s).not_to include("Demo@1234", user.password_digest)
    expect(response.headers["Access-Control-Allow-Credentials"]).to eq("true")

    set_cookie = Array(response.headers["Set-Cookie"]).join("\n")
    expect(set_cookie).to match(/refresh_token=/)
    expect(set_cookie).to match(/HttpOnly/i)
    expect(set_cookie).to match(/SameSite=Lax/i)
    expect(set_cookie).to match(%r{Path=/api/v1/auth}i)

    session = UserSession.find_by_token(response.cookies["refresh_token"])
    expect(session.user).to eq(user)
    expect(AccessToken.decode(data["access_token"])).to include(
      "sid" => session.id,
      "role" => Role::HR
    )
  end

  it "signs in a standard employee with the employee role" do
    user = create(:user, email: "priya@demo.test")

    sign_in(email: user.email)

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("data", "user", "role")).to eq(Role::STANDARD_EMPLOYEE)
  end

  it "rejects a wrong password with a generic error and creates no session" do
    user = create(:user, :hr, email: "hr@demo.test")

    expect { sign_in(email: user.email, password: "wrong-password") }
      .not_to change(UserSession, :count)

    expect_generic_failure
  end

  it "rejects an unknown email with the same generic error" do
    expect { sign_in(email: "nobody@demo.test") }
      .not_to change(UserSession, :count)

    expect_generic_failure
  end

  it "rejects an inactive account with the same generic error" do
    user = create(:user, email: "inactive@demo.test", active: false)

    expect { sign_in(email: user.email) }
      .not_to change(UserSession, :count)

    expect_generic_failure
  end

  it "treats missing credentials as invalid" do
    expect { post "/api/v1/auth/sign_in", params: {}, as: :json }
      .not_to change(UserSession, :count)

    expect_generic_failure
  end
end
