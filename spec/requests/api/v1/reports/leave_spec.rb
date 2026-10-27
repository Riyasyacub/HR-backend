require "rails_helper"

RSpec.describe "Leave report", type: :request do
  let(:hr_headers) { authentication_headers(create(:user, :hr)) }
  let!(:earned) { create(:leave_type, name: "Earned", default_entitlement: 6) }
  let!(:unpaid) { create(:leave_type, :unpaid) }

  def leave_report(params = { year: 2026 }, headers = hr_headers)
    get("/api/v1/reports/leave", params:, headers:)
    response.parsed_body
  end

  def employee_with_leave(used: 0, unpaid_days: 0, **attributes)
    employee = create(:employee, start_date: Date.new(2026, 1, 1), **attributes)
    create(:leave_ledger_entry, employee:, leave_type: earned, days: 6)
    create(:leave_ledger_entry, employee:, leave_type: earned, entry_type: "used", days: -used) if used.positive?
    unpaid_days.times { |offset| create(:leave_record, employee:, leave_type: unpaid, leave_date: Date.new(2026, 11, 2 + offset)) }
    employee
  end

  it "shows entitled, used and remaining per tracked type and unpaid days for each employee (TC-S10-04)" do
    priya = employee_with_leave(used: 2, unpaid_days: 1, employee_id: "EMP102", first_name: "Priya", last_name: "Sharma")

    expect(leave_report["data"]).to eq([ {
      "id" => priya.id, "employee_id" => "EMP102", "name" => "Priya Sharma",
      "balances" => [ { "leave_type" => "Earned", "entitled" => 6, "used" => 2, "remaining" => 4 } ], "unpaid_days" => 1
    } ])
  end

  it "reconciles with the employee's leave balances (AC-04)" do
    priya = employee_with_leave(used: 3)
    row = leave_report["data"].first

    get("/api/v1/employees/#{priya.id}/leave_balances", params: { year: 2026 }, headers: hr_headers)

    expect(row["balances"]).to eq(response.parsed_body["data"])
  end

  it "excludes other years" do
    priya = employee_with_leave
    create(:leave_ledger_entry, employee: priya, leave_type: earned, year: 2025, days: 9)
    create(:leave_record, employee: create(:employee, start_date: Date.new(2025, 1, 1)), leave_type: unpaid, leave_date: Date.new(2025, 12, 1))

    body = leave_report

    expect(body["data"].first["balances"].first["entitled"]).to eq(6)
    expect(body["meta"]["totals"]["unpaid_days"]).to eq(0)
  end

  it "totals every filtered employee, not just the page" do
    3.times { employee_with_leave(used: 1, unpaid_days: 1) }
    employee_with_leave(used: 5, country: "USA")

    body = leave_report(year: 2026, country: "India", per_page: 2)

    expect(body["data"].size).to eq(2)
    expect(body["meta"]).to include("page" => 1, "per_page" => 2, "total" => 3, "year" => 2026)
    expect(body["meta"]["totals"]).to eq(
      "balances" => [ { "leave_type" => "Earned", "entitled" => 18, "used" => 3, "remaining" => 15 } ], "unpaid_days" => 3
    )
  end

  it "shows a manager only their subtree and denies other employees (AC-06)" do
    manager_user = create(:user)
    report = employee_with_leave(manager: create(:employee, user: manager_user))
    employee_with_leave

    expect(leave_report({ year: 2026 }, authentication_headers(manager_user))["data"].pluck("id")).to eq([ report.id ])

    plain_user = create(:user)
    create(:employee, user: plain_user)
    leave_report({ year: 2026 }, authentication_headers(plain_user))
    expect(response).to have_http_status(:forbidden)
  end

  it "uses a fixed number of ledger and leave record queries" do
    3.times { employee_with_leave(used: 1, unpaid_days: 1) }
    queries = []
    callback = ->(*, payload) { queries << payload[:sql] if payload[:sql].match?(/FROM "(leave_ledger_entries|leave_records|leave_types)"/) }
    headers = hr_headers

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { leave_report({ year: 2026 }, headers) }

    expect(queries.size).to eq(5)
  end
end
