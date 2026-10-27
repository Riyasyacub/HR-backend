require "rails_helper"

RSpec.describe "Leave records", type: :request do
  let(:hr_headers) { authentication_headers(create(:user, :hr)) }
  let(:earned) { create(:leave_type, name: "Earned") }
  let(:arjun_user) { create(:user) }
  let(:priya_user) { create(:user) }
  let!(:arjun) { create(:employee, employee_id: "EMP901", user: arjun_user, start_date: Date.new(2026, 1, 1)) }
  let!(:priya) { create(:employee, employee_id: "EMP902", user: priya_user, manager: arjun, start_date: Date.new(2026, 1, 1)) }
  let!(:john) { create(:employee, employee_id: "EMP903", start_date: Date.new(2026, 1, 1)) }
  let(:wednesday) { Date.new(2026, 10, 28) }

  def leave_for(employee, date = wednesday) = create(:leave_record, employee:, leave_type: earned, leave_date: date)

  def fetch_leave_records(headers, params = {})
    get("/api/v1/leave_records", params:, headers:)
    response.parsed_body
  end

  it "lists all leave records newest first for HR" do
    leave_for(john, wednesday - 1)
    priya_leave = leave_for(priya)

    body = fetch_leave_records(hr_headers)

    expect(body["data"].first).to eq(
      "id" => priya_leave.id, "leave_date" => "2026-10-28", "leave_type" => "Earned",
      "reason" => "Family function", "payroll_deduction" => false,
      "employee" => { "id" => priya.id, "employee_id" => "EMP902", "name" => "Ravi Kumar" }
    )
    expect(body["data"].size).to eq(2)
    expect(body["meta"]).to eq("page" => 1, "per_page" => 25, "total" => 2)
  end

  it "filters by leave date" do
    leave_for(john, wednesday - 1)
    leave_for(priya)

    expect(fetch_leave_records(hr_headers, leave_date: "2026-10-28")["data"].pluck("employee").pluck("employee_id")).to eq(%w[EMP902])
  end

  it "filters by employee" do
    leave_for(john)
    leave_for(priya)

    expect(fetch_leave_records(hr_headers, employee_id: priya.id)["data"].map { _1["employee"]["employee_id"] }).to eq(%w[EMP902])
  end

  it "keeps the viewer's scope when filtering by an employee outside it" do
    leave_for(john)

    expect(fetch_leave_records(authentication_headers(arjun_user), employee_id: john.id)["data"]).to be_empty
  end

  it "shows a manager their own and their subtree's records only (AC-07)" do
    [ arjun, priya, john ].each { leave_for(_1) }

    ids = fetch_leave_records(authentication_headers(arjun_user))["data"].map { _1["employee"]["employee_id"] }

    expect(ids).to contain_exactly("EMP901", "EMP902")
  end

  it "shows an employee only their own records (AC-07)" do
    [ arjun, priya ].each { leave_for(_1) }

    ids = fetch_leave_records(authentication_headers(priya_user))["data"].map { _1["employee"]["employee_id"] }

    expect(ids).to eq(%w[EMP902])
  end

  it "returns an empty list for a user without an employee record" do
    leave_for(john)

    expect(fetch_leave_records(authentication_headers(create(:user)))["data"]).to be_empty
  end

  it "denies a manager a record outside their subtree (TC-S06-09)" do
    get "/api/v1/leave_records/#{leave_for(john).id}", headers: authentication_headers(arjun_user)

    expect(response).to have_http_status(:forbidden)
  end

  it "lets an employee open their own record" do
    record = leave_for(priya)

    get "/api/v1/leave_records/#{record.id}", headers: authentication_headers(priya_user)

    expect(response.parsed_body["data"]["id"]).to eq(record.id)
  end

  it "loads employees and leave types without N+1 queries" do
    [ arjun, priya, john ].each { leave_for(_1) }
    queries = []
    callback = ->(*, payload) { queries << payload[:sql] if payload[:sql].match?(/FROM "(employees|leave_types)"/) }

    headers = hr_headers
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { fetch_leave_records(headers) }

    expect(queries.size).to be <= 2
  end

  it "rejects an unauthenticated request" do
    get "/api/v1/leave_records"

    expect(response).to have_http_status(:unauthorized)
  end
end
