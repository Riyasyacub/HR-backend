require "rails_helper"

RSpec.describe "Trends report", type: :request do
  let(:hr_headers) { authentication_headers(create(:user, :hr)) }

  around { |example| travel_to(Date.new(2026, 11, 15)) { example.run } }

  def trends(params = { months: 3 }, headers = hr_headers)
    get("/api/v1/reports/trends", params:, headers:)
    response.parsed_body["data"]
  end

  it "returns month labels ending with the current month" do
    expect(trends["months"]).to eq(%w[2026-09 2026-10 2026-11])
    expect(trends({})["months"].size).to eq(12)
  end

  it "counts headcount by month end and joiners in each month" do
    create(:employee, start_date: Date.new(2025, 1, 1))
    create(:employee, start_date: Date.new(2026, 10, 3))
    create(:employee, start_date: Date.new(2026, 11, 20))
    create(:employee, start_date: Date.new(2026, 9, 1), status: "onboarding")

    data = trends

    expect(data["headcount"]).to eq([ 1, 2, 3 ])
    expect(data["joiners"]).to eq([ 0, 1, 1 ])
  end

  it "counts leave days per type in each month" do
    earned = create(:leave_type, name: "Earned")
    unpaid = create(:leave_type, :unpaid)
    employee = create(:employee, start_date: Date.new(2026, 1, 1))
    create(:leave_record, employee:, leave_type: earned, leave_date: Date.new(2026, 10, 5))
    create(:leave_record, employee:, leave_type: earned, leave_date: Date.new(2026, 11, 2))
    create(:leave_record, employee:, leave_type: unpaid, leave_date: Date.new(2026, 11, 3))
    create(:leave_record, employee:, leave_type: earned, leave_date: Date.new(2026, 6, 1))

    expect(trends["leave_days"]).to eq([ { "leave_type" => "Earned", "values" => [ 0, 1, 1 ] }, { "leave_type" => "Unpaid", "values" => [ 0, 0, 1 ] } ])
  end

  it "totals payroll per currency from generated and paid runs only" do
    october = create(:payroll_run, month: Date.new(2026, 10, 1), status: "paid", paid_on: Date.new(2026, 11, 1), calculation_status: "completed")
    create(:payroll_line, payroll_run: october, total: 90_000)
    create(:payroll_line, payroll_run: october, country: "USA", currency: "USD", total: 8_000)
    create(:payroll_line, payroll_run: create(:payroll_run, month: Date.new(2026, 11, 1)), total: 5_000)

    expect(trends["payroll_totals"]).to eq([ { "currency" => "INR", "values" => %w[0.00 90000.00 0.00] },
      { "currency" => "USD", "values" => %w[0.00 8000.00 0.00] } ])
  end

  it "limits a manager to their subtree without payroll and denies other employees" do
    manager_user = create(:user)
    create(:employee, manager: create(:employee, user: manager_user, start_date: Date.new(2025, 1, 1)), start_date: Date.new(2026, 11, 1))
    create(:employee, start_date: Date.new(2026, 11, 2))

    data = trends({ months: 3 }, authentication_headers(manager_user))
    expect(data["joiners"]).to eq([ 0, 0, 1 ])
    expect(data["payroll_totals"]).to be_nil

    plain_user = create(:user)
    create(:employee, user: plain_user)
    trends({ months: 3 }, authentication_headers(plain_user))
    expect(response).to have_http_status(:forbidden)
  end

  it "uses the same number of queries for any window" do
    count = lambda do |months|
      queries = 0
      callback = ->(*, payload) { queries += 1 unless payload[:name] == "SCHEMA" }
      headers = hr_headers
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { trends({ months: }, headers) }
      queries
    end

    expect(count.call(24)).to eq(count.call(3))
  end
end
