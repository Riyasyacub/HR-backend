require "rails_helper"

RSpec.describe "Report exports", type: :request do
  let(:hr_headers) { authentication_headers(create(:user, :hr)) }

  def export(report, params, headers = hr_headers)
    get("/api/v1/reports/#{report}", params: params.merge(format: "xlsx"), headers:)
    file = Tempfile.new([ report, ".xlsx" ]).tap { |f| f.binmode && f.write(response.body) && f.flush }
    Roo::Excelx.new(file.path).sheet(0).to_a
  end

  def json(report, params, headers = hr_headers)
    get("/api/v1/reports/#{report}", params:, headers:)
    response.parsed_body
  end

  it "exports the filtered headcount with a total row matching the screen (TC-S10-09)" do
    create_list(:employee, 2, country: "India")
    create(:employee, country: "India", status: "onboarding")
    create(:employee, country: "USA")
    screen = json("headcount", { group_by: "department", country: "India" })

    rows = export("headcount", { group_by: "department", country: "India" })

    expect(response.headers["Content-Disposition"]).to match(/filename="headcount-\d{4}-\d{2}-\d{2}\.xlsx"/)
    expect(rows.first).to eq([ "Department", "Headcount", "Onboarding" ])
    expect(rows[1..-2]).to eq(screen["data"].map(&:values))
    expect(rows.last).to eq([ "Total", 2, 1 ])
  end

  it "exports every filtered joiner, not just the first page" do
    create_list(:employee, 3, start_date: Date.new(2026, 11, 4))

    rows = export("joiners", { from: "2026-11-01", to: "2026-11-30", per_page: 1 })

    expect(rows.first).to eq([ "Employee ID", "Name", "Country", "Department", "Start date" ])
    expect(rows.size).to eq(4)
    expect(rows[1][4]).to eq(Date.new(2026, 11, 4))
  end

  it "exports the payroll totals shown on screen" do
    run = create(:payroll_run, status: "generated", calculation_status: "completed")
    create(:payroll_line, payroll_run: run, total: 90_000, unpaid_deduction: 10_000)
    screen = json("payroll", { year: 2026 })

    rows = export("payroll", { year: 2026 })

    expect(rows.first).to eq([ "Month", "Country", "Currency", "Employees", "Monthly gross", "Unpaid deduction", "Total" ])
    expect(rows[1]).to eq(screen["data"].first.values.each_with_index.map { |value, index| index > 3 ? value.to_d : value })
  end

  it "gives a manager exports without salary, CTC or bank columns, and denies payroll (TC-S10-10)" do
    manager_user = create(:user)
    create(:employee, manager: create(:employee, user: manager_user), start_date: Date.new(2026, 11, 4))
    headers = authentication_headers(manager_user)

    headers_row = export("headcount", { group_by: "country" }, headers).first + export("joiners", { from: "2026-11-01", to: "2026-11-30" }, headers).first

    expect(headers_row.join(" ")).not_to match(/salary|ctc|bank|account|gross/i)
    get("/api/v1/reports/payroll", params: { year: 2026, format: "xlsx" }, headers:)
    expect(response).to have_http_status(:forbidden)
  end

  describe "leave export" do
    let!(:earned) { create(:leave_type, name: "Earned", default_entitlement: 6) }

    def employee_with_entitlement(**attributes)
      create(:employee, start_date: Date.new(2026, 1, 1), **attributes).tap do |employee|
        create(:leave_ledger_entry, employee:, leave_type: earned)
      end
    end

    it "exports one row per filtered employee and a total matching the screen" do
      2.times { employee_with_entitlement }
      employee_with_entitlement(country: "USA")
      screen = json("leave", { year: 2026, country: "India", per_page: 1 })

      rows = export("leave", { year: 2026, country: "India", per_page: 1 })

      expect(rows.size).to eq(4)
      expect(rows[1]).to eq([ screen["data"].first["employee_id"], screen["data"].first["name"], 6, 0, 6, 0 ])
      expect(rows.last).to eq([ "Total", nil, *screen["meta"]["totals"]["balances"].first.values_at("entitled", "used", "remaining"), 0 ])
    end

    it "limits a manager's export to their subtree" do
      manager_user = create(:user)
      report = employee_with_entitlement(manager: create(:employee, user: manager_user))
      employee_with_entitlement

      rows = export("leave", { year: 2026 }, authentication_headers(manager_user))

      expect(rows[1..-2].map(&:first)).to eq([ report.employee_id ])
    end
  end
end
