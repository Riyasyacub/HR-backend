require "rails_helper"

RSpec.describe "Settings countries", type: :request do
  def get_countries(headers = {})
    get "/api/v1/settings/countries", headers:
  end

  it "lists the three countries and currencies for HR" do
    get_countries(authentication_headers(create(:user, :hr)))

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq(
      "data" => [
        { "name" => "India", "currency" => "INR" },
        { "name" => "USA", "currency" => "USD" },
        { "name" => "Canada", "currency" => "CAD" }
      ],
      "meta" => { "page" => 1, "per_page" => 3, "total" => 3 }
    )
  end

  it "rejects an employee" do
    get_countries(authentication_headers(create(:user)))

    expect(response).to have_http_status(:forbidden)
    expect(response.parsed_body).to eq(
      "error" => {
        "code" => "forbidden",
        "message" => "You are not authorized to perform this action",
        "details" => []
      }
    )
  end

  it "rejects an unauthenticated request" do
    get_countries

    expect(response).to have_http_status(:unauthorized)
    expect(response.parsed_body.dig("error", "code")).to eq("invalid_token")
  end
end
