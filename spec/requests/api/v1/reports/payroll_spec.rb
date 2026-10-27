require "rails_helper"

RSpec.describe "Payroll totals report", type: :request do
  let(:hr_headers) { authentication_headers(create(:user, :hr)) }

  def payroll_report(params = { year: 2026 }, headers = hr_headers)
    get("/api/v1/reports/payroll", params:, headers:)
    response.parsed_body
  end

  def run_with_lines(month, status: "generated", lines: [ {} ])
    run = create(:payroll_run, month:, status:, paid_on: (Date.new(2026, 12, 1) if status == "paid"), calculation_status: "completed")
    lines.each { |attributes| create(:payroll_line, payroll_run: run, **attributes) }
    run
  end

  it "groups generated and paid runs by month, country and currency without conversion (TC-S10-05)" do
    run_with_lines(Date.new(2026, 10, 1), status: "paid", lines: [ { monthly_gross: 100_000, unpaid_deduction: 5_000, total: 95_000 } ])
    run_with_lines(Date.new(2026, 11, 1), lines: [ {}, { country: "USA", currency: "USD", monthly_gross: 8_000, total: 8_000 } ])

    expect(payroll_report["data"]).to eq([
      { "month" => "2026-10", "country" => "India", "currency" => "INR", "employees" => 1,
        "monthly_gross" => "100000.00", "unpaid_deduction" => "5000.00", "total" => "95000.00" },
      { "month" => "2026-11", "country" => "India", "currency" => "INR", "employees" => 1,
        "monthly_gross" => "100000.00", "unpaid_deduction" => "0.00", "total" => "100000.00" },
      { "month" => "2026-11", "country" => "USA", "currency" => "USD", "employees" => 1,
        "monthly_gross" => "8000.00", "unpaid_deduction" => "0.00", "total" => "8000.00" }
    ])
    expect(response.parsed_body["meta"]).to eq("year" => 2026)
  end

  it "excludes draft runs" do
    run_with_lines(Date.new(2026, 11, 1), status: "draft")

    expect(payroll_report["data"]).to eq([])
  end

  it "reconciles with the run's own totals (AC-05)" do
    run = run_with_lines(Date.new(2026, 11, 1), lines: [ { total: 90_000, unpaid_deduction: 10_000 }, { total: 100_000 } ])
    report_row = payroll_report["data"].first

    get("/api/v1/payroll_runs/#{run.id}", headers: hr_headers)

    expect(report_row.except("month")).to eq(response.parsed_body["data"]["totals"].first)
  end

  it "filters by year and country" do
    run_with_lines(Date.new(2025, 12, 1))
    run_with_lines(Date.new(2026, 11, 1), lines: [ {}, { country: "USA", currency: "USD" } ])

    expect(payroll_report(year: 2026, country: "USA")["data"].pluck("month", "country")).to eq([ [ "2026-11", "USA" ] ])
  end

  it "denies a manager (payroll totals are HR only)" do
    manager_user = create(:user)
    create(:employee, manager: create(:employee, user: manager_user))

    payroll_report({ year: 2026 }, authentication_headers(manager_user))

    expect(response).to have_http_status(:forbidden)
  end
end
