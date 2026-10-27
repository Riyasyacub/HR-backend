require "rails_helper"

RSpec.describe "Payroll runs", type: :request do
  let(:hr) { create(:user, :hr) }
  let(:hr_headers) { authentication_headers(hr) }

  def create_run(month, headers = hr_headers)
    post("/api/v1/payroll_runs", params: { month: }, as: :json, headers:)
  end

  it "creates a draft run and queues its calculation" do
    expect { create_run("2026-11") }.to have_enqueued_job(CalculatePayrollRunJob)

    expect(response).to have_http_status(:accepted)
    expect(response.parsed_body["data"]).to include("month" => "2026-11-01", "status" => "draft",
      "calculation_status" => "queued", "calculation_error" => nil)
    expect(PayrollRun.last.created_by).to eq(hr)
  end

  it "rejects a second run for the same month" do
    create(:payroll_run, month: Date.new(2026, 11, 1))

    create_run("2026-11")

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body["error"]["details"]).to include("Month has already been taken")
  end

  it "rejects an invalid month" do
    create_run("November")

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body["error"]["code"]).to eq("validation_failed")
  end

  it "lists runs newest month first" do
    create(:payroll_run, month: Date.new(2026, 10, 1))
    create(:payroll_run, month: Date.new(2026, 11, 1))

    get("/api/v1/payroll_runs", headers: hr_headers)

    expect(response.parsed_body["data"].pluck("month")).to eq(%w[2026-11-01 2026-10-01])
    expect(response.parsed_body["meta"]).to eq("page" => 1, "per_page" => 25, "total" => 2)
  end

  it "shows totals per country and currency without conversion (TC-S08-07) and counts blocking issues (TC-S08-05)" do
    run = create(:payroll_run, calculation_status: "completed")
    create(:payroll_line, payroll_run: run, monthly_gross: 100_000, unpaid_deduction: 10_000, total: 90_000)
    create(:payroll_line, payroll_run: run, monthly_gross: 50_000, total: 50_000, blocking_issues: [ "missing account number" ])
    create(:payroll_line, payroll_run: run, country: "USA", currency: "USD", monthly_gross: 8_000, total: 8_000)
    create(:payroll_line, payroll_run: run, country: "Ecuador", currency: "USD", monthly_gross: 3_000, total: 3_000)

    get("/api/v1/payroll_runs/#{run.id}", headers: hr_headers)

    expect(response.parsed_body["data"]).to include(
      "blocking_issues_count" => 1,
      "totals" => [
        { "country" => "Ecuador", "currency" => "USD", "employees" => 1, "monthly_gross" => "3000.00", "unpaid_deduction" => "0.00", "total" => "3000.00" },
        { "country" => "India", "currency" => "INR", "employees" => 2, "monthly_gross" => "150000.00", "unpaid_deduction" => "10000.00", "total" => "140000.00" },
        { "country" => "USA", "currency" => "USD", "employees" => 1, "monthly_gross" => "8000.00", "unpaid_deduction" => "0.00", "total" => "8000.00" }
      ]
    )
  end

  it "denies a manager create, list and show (TC-S08-08, AC-06)" do
    manager_user = create(:user)
    create(:employee, manager: create(:employee, user: manager_user))
    headers = authentication_headers(manager_user)
    run = create(:payroll_run, month: Date.new(2026, 10, 1))

    create_run("2026-11", headers)
    expect(response).to have_http_status(:forbidden)
    get("/api/v1/payroll_runs", headers:)
    expect(response).to have_http_status(:forbidden)
    get("/api/v1/payroll_runs/#{run.id}", headers:)
    expect(response).to have_http_status(:forbidden)
  end

  describe "recalculate" do
    def recalculate(run, headers = hr_headers) = post("/api/v1/payroll_runs/#{run.id}/recalculate", headers:)

    it "queues a completed draft for recalculation" do
      run = create(:payroll_run, calculation_status: "completed")

      expect { recalculate(run) }.to have_enqueued_job(CalculatePayrollRunJob).with(run.id)

      expect(response).to have_http_status(:accepted)
      expect(run.reload.calculation_status).to eq("queued")
    end

    it "rejects a run that is already queued or processing" do
      %w[queued processing].each_with_index do |calculation_status, index|
        recalculate(create(:payroll_run, month: Date.new(2026, index + 1, 1), calculation_status:))

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["error"]["code"]).to eq("not_recalculable")
      end
    end

    it "rejects a generated run (BR-PAY-06)" do
      recalculate(create(:payroll_run, status: "generated", calculation_status: "completed"))

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "lines" do
    let(:run) { create(:payroll_run, calculation_status: "completed") }
    let(:priya) { create(:employee, employee_id: "EMP902", first_name: "Priya", last_name: "Sharma") }

    def fetch_lines(params = {}, headers = hr_headers)
      get("/api/v1/payroll_runs/#{run.id}/lines", params:, headers:)
      response.parsed_body
    end

    it "lists lines in employee ID order with amounts and issues" do
      create(:payroll_line, payroll_run: run, employee: create(:employee, employee_id: "EMP903"))
      create(:payroll_line, payroll_run: run, employee: priya, working_days: 20, unpaid_days: 2,
        unpaid_deduction: 10_000, total: 90_000)

      body = fetch_lines

      expect(body["data"].first).to eq(
        "id" => run.payroll_lines.find_by(employee: priya).id,
        "employee" => { "id" => priya.id, "employee_id" => "EMP902", "name" => "Priya Sharma" },
        "country" => "India", "currency" => "INR", "monthly_gross" => "100000.00", "working_days" => 20,
        "unpaid_days" => 2, "unpaid_deduction" => "10000.00", "total" => "90000.00", "blocking_issues" => []
      )
      expect(body["meta"]).to eq("page" => 1, "per_page" => 25, "total" => 2)
    end

    it "returns only lines with blocking issues when asked (TC-S08-05)" do
      create(:payroll_line, payroll_run: run)
      create(:payroll_line, payroll_run: run, employee: priya, blocking_issues: [ "missing account number" ])

      expect(fetch_lines(issues_only: "true")["data"].map { _1["employee"]["employee_id"] }).to eq(%w[EMP902])
    end

    it "loads employees without N+1 queries" do
      3.times { create(:payroll_line, payroll_run: run) }
      queries = []
      callback = ->(*, payload) { queries << payload[:sql] if payload[:sql].include?('FROM "employees"') }
      headers = hr_headers

      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { fetch_lines({}, headers) }

      expect(queries.size).to eq(1)
    end

    it "denies a manager recalculate and lines (TC-S08-08)" do
      manager_user = create(:user)
      create(:employee, manager: create(:employee, user: manager_user))
      headers = authentication_headers(manager_user)

      post("/api/v1/payroll_runs/#{run.id}/recalculate", headers:)
      expect(response).to have_http_status(:forbidden)
      fetch_lines({}, headers)
      expect(response).to have_http_status(:forbidden)
    end
  end
end
