require "rails_helper"

RSpec.describe "Joiners report", type: :request do
  let(:hr_headers) { authentication_headers(create(:user, :hr)) }
  let(:november) { { from: "2026-11-01", to: "2026-11-30" } }

  def joiners(params, headers = hr_headers)
    get("/api/v1/reports/joiners", params:, headers:)
    response.parsed_body
  end

  it "lists employees who started in the period with their start dates (TC-S10-02, AC-02)" do
    later = create(:employee, employee_id: "EMP300", first_name: "Nisha", last_name: "Rao", start_date: Date.new(2026, 11, 20))
    earlier = create(:employee, employee_id: "EMP301", start_date: Date.new(2026, 11, 2))

    body = joiners(november)

    expect(body["data"].pluck("employee_id", "start_date")).to eq([ [ "EMP301", "2026-11-02" ], [ "EMP300", "2026-11-20" ] ])
    expect(body["data"].last).to include("id" => later.id, "name" => "Nisha Rao", "country" => "India",
      "department" => later.department.name)
    expect(body["data"].first["id"]).to eq(earlier.id)
  end

  it "excludes starts outside the period and applies the country filter" do
    create(:employee, start_date: Date.new(2026, 10, 31))
    create(:employee, start_date: Date.new(2026, 12, 1))
    create(:employee, country: "USA", start_date: Date.new(2026, 11, 5))
    india = create(:employee, start_date: Date.new(2026, 11, 5))

    expect(joiners(november.merge(country: "India"))["data"].pluck("id")).to eq([ india.id ])
  end

  it "paginates with the total in meta" do
    create_list(:employee, 3, start_date: Date.new(2026, 11, 3))

    body = joiners(november.merge(page: 2, per_page: 2))

    expect(body["data"].size).to eq(1)
    expect(body["meta"]).to eq("page" => 2, "per_page" => 2, "total" => 3)
  end

  it "shows a manager only joiners in their subtree (AC-06)" do
    manager_user = create(:user)
    report = create(:employee, manager: create(:employee, user: manager_user), start_date: Date.new(2026, 11, 9))
    create(:employee, start_date: Date.new(2026, 11, 9))

    expect(joiners(november, authentication_headers(manager_user))["data"].pluck("id")).to eq([ report.id ])
  end

  it "rejects a missing, invalid or reversed period" do
    [ {}, { from: "soon", to: "2026-11-30" }, { from: "2026-11-30", to: "2026-11-01" } ].each do |params|
      expect(joiners(params).dig("error", "code")).to eq("invalid_period")
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  it "denies an employee without reports" do
    employee_user = create(:user)
    create(:employee, user: employee_user)

    joiners(november, authentication_headers(employee_user))

    expect(response).to have_http_status(:forbidden)
  end

  it "loads departments without N+1 queries" do
    create_list(:employee, 3, start_date: Date.new(2026, 11, 3))
    queries = []
    callback = ->(*, payload) { queries << payload[:sql] if payload[:sql].include?('FROM "departments"') }
    headers = hr_headers

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { joiners(november, headers) }

    expect(queries.size).to eq(1)
  end
end
