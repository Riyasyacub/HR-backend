require "rails_helper"

RSpec.describe "Employees", type: :request do
  let(:hr_headers) { authentication_headers(create(:user, :hr)) }

  def get_employees(headers = hr_headers, params = {})
    get "/api/v1/employees", params:, headers:
  end

  it "lists employees ordered by employee ID with department details" do
    engineering = create(:department, name: "Engineering", code: "ENG")
    sales = create(:department, name: "Sales", code: "SAL")
    ravi = create(:employee, employee_id: "EMP101", first_name: "Ravi", last_name: "Kumar",
      work_email: "ravi@demo.test", department: engineering, job_title: "Software Engineer",
      start_date: Date.new(2026, 1, 1))
    anita = create(:employee, employee_id: "EMP100", first_name: "Anita", last_name: "Sharma",
      work_email: "anita@demo.test", department: sales, job_title: "Sales Lead",
      start_date: Date.new(2026, 2, 1))

    get_employees

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq(
      "data" => [
        {
          "id" => anita.id, "employee_id" => "EMP100", "first_name" => "Anita",
          "last_name" => "Sharma", "work_email" => "anita@demo.test", "country" => "India",
          "currency" => "INR", "job_title" => "Sales Lead", "start_date" => "2026-02-01",
          "status" => "active", "department" => { "id" => sales.id, "name" => "Sales" }
        },
        {
          "id" => ravi.id, "employee_id" => "EMP101", "first_name" => "Ravi",
          "last_name" => "Kumar", "work_email" => "ravi@demo.test", "country" => "India",
          "currency" => "INR", "job_title" => "Software Engineer", "start_date" => "2026-01-01",
          "status" => "active", "department" => { "id" => engineering.id, "name" => "Engineering" }
        }
      ],
      "meta" => { "page" => 1, "per_page" => 25, "total" => 2 }
    )
    expect(response.parsed_body.dig("data", 0)).not_to include(
      "bank_name", "account_number", "annual_ctc"
    )
  end

  it "paginates employees" do
    create_list(:employee, 3)

    get_employees(hr_headers, page: 2, per_page: 2)

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["data"].size).to eq(1)
    expect(response.parsed_body["meta"]).to eq("page" => 2, "per_page" => 2, "total" => 3)
  end

  it "preloads departments instead of querying per employee" do
    create_list(:employee, 3)
    department_queries = []
    subscriber = lambda do |_name, _start, _finish, _id, payload|
      department_queries << payload[:sql] if payload[:sql].include?("departments")
    end

    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
      get_employees
    end

    expect(department_queries.size).to eq(1)
  end

  it "denies a non-HR user" do
    get_employees(authentication_headers(create(:user)))

    expect(response).to have_http_status(:forbidden)
    expect(response.parsed_body.dig("error", "code")).to eq("forbidden")
  end

  it "rejects an unauthenticated request" do
    get_employees({})

    expect(response).to have_http_status(:unauthorized)
    expect(response.parsed_body.dig("error", "code")).to eq("invalid_token")
  end

  describe "GET /api/v1/employees/:id" do
    let(:department) { create(:department, name: "Engineering", code: "ENG") }
    let(:employee) do
      create(:employee, employee_id: "EMP101", first_name: "Ravi", last_name: "Kumar",
        work_email: "ravi@demo.test", department:, job_title: "Software Engineer",
        start_date: Date.new(2026, 1, 1), bank_name: "HDFC Bank",
        ifsc: "HDFC0001234", account_number: "123456789012")
    end
    let!(:compensation) do
      create(:compensation, employee:, annual_ctc: 1_200_000).tap do |record|
        create(:compensation_component, compensation: record, name: "Basic",
          annual_amount: 1_200_000)
      end
    end

    def get_employee(id = employee.id, headers = hr_headers)
      get "/api/v1/employees/#{id}", headers:
    end

    it "returns an employee profile with bank and compensation for HR" do
      get_employee

      expect(response).to have_http_status(:ok)
      component = compensation.components.first
      expect(response.parsed_body).to eq(
        "data" => {
          "id" => employee.id, "employee_id" => "EMP101", "first_name" => "Ravi",
          "last_name" => "Kumar", "work_email" => "ravi@demo.test", "country" => "India",
          "currency" => "INR", "job_title" => "Software Engineer", "start_date" => "2026-01-01",
          "status" => "active", "department" => { "id" => department.id, "name" => "Engineering" },
          "bank" => {
            "bank_name" => "HDFC Bank", "ifsc" => "HDFC0001234",
            "account_number" => "123456789012"
          },
          "compensation" => {
            "id" => compensation.id, "effective_date" => "2026-01-01",
            "annual_ctc" => "1200000.00", "currency" => "INR",
            "components" => [
              { "id" => component.id, "name" => "Basic", "annual_amount" => "1200000.00" }
            ]
          }
        }
      )
    end

    it "allows an employee to view their own profile" do
      user = create(:user, email: "priya@demo.test")
      employee.update!(user:)

      get_employee(employee.id, authentication_headers(user))

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "id")).to eq(employee.id)
      expect(response.parsed_body.dig("data", "bank", "account_number")).to eq("123456789012")
      expect(response.parsed_body.dig("data", "compensation", "annual_ctc")).to eq("1200000.00")
    end

    it "denies an employee access to another employee's profile" do
      get_employee(employee.id, authentication_headers(create(:user)))

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body.dig("error", "code")).to eq("forbidden")
    end

    it "returns not found for an unknown employee" do
      get_employee(999_999)

      expect(response).to have_http_status(:not_found)
    end

    it "rejects an unauthenticated profile request" do
      get_employee(employee.id, {})

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body.dig("error", "code")).to eq("invalid_token")
    end
  end

  describe "POST /api/v1/employees" do
    let(:department) { create(:department, name: "Engineering", code: "ENG") }
    let(:payload) do
      {
        employee: {
          employee_id: "EMP101",
          first_name: "Ravi",
          last_name: "Kumar",
          work_email: "ravi@demo.test",
          country: "India",
          department_id: department.id,
          job_title: "Software Engineer",
          start_date: "2026-01-01",
          bank_name: "HDFC Bank",
          ifsc: "HDFC0001234",
          account_number: "123456789012",
          status: "active"
        },
        compensation: {
          components: [
            { name: "Basic", annual_amount: 1_000_000 },
            { name: "Allowance", annual_amount: 200_000 }
          ]
        }
      }
    end

    def post_employee(body = payload, headers = hr_headers)
      post "/api/v1/employees", params: body, as: :json, headers:
    end

    it "creates an employee with derived compensation for HR" do
      expect { post_employee }.to change(Employee, :count).by(1)

      expect(response).to have_http_status(:created)

      employee = Employee.find_by!(employee_id: "EMP101")
      compensation = employee.compensations.first
      basic = compensation.components.find_by!(name: "Basic")
      allowance = compensation.components.find_by!(name: "Allowance")

      expect(response.parsed_body).to eq(
        "data" => {
          "id" => employee.id,
          "employee_id" => "EMP101",
          "first_name" => "Ravi",
          "last_name" => "Kumar",
          "work_email" => "ravi@demo.test",
          "country" => "India",
          "currency" => "INR",
          "job_title" => "Software Engineer",
          "start_date" => "2026-01-01",
          "status" => "active",
          "department" => { "id" => department.id, "name" => "Engineering" },
          "compensation" => {
            "id" => compensation.id,
            "effective_date" => "2026-01-01",
            "annual_ctc" => "1200000.00",
            "currency" => "INR",
            "components" => [
              { "id" => basic.id, "name" => "Basic", "annual_amount" => "1000000.00" },
              { "id" => allowance.id, "name" => "Allowance",
                "annual_amount" => "200000.00" }
            ]
          }
        }
      )
    end

    it "ignores a supplied annual CTC and derives it from components" do
      post_employee(payload.deep_merge(compensation: { annual_ctc: 999 }))

      expect(response).to have_http_status(:created)
      expect(response.parsed_body.dig("data", "compensation", "annual_ctc")).to eq("1200000.00")
    end

    it "derives currency from country and ignores a supplied currency" do
      post_employee(payload.deep_merge(employee: { country: "Canada", currency: "USD" }))

      expect(response).to have_http_status(:created)
      expect(response.parsed_body.dig("data", "country")).to eq("Canada")
      expect(response.parsed_body.dig("data", "currency")).to eq("CAD")
      expect(response.parsed_body.dig("data", "compensation", "currency")).to eq("CAD")
    end

    it "rejects a duplicate employee ID with field details" do
      create(:employee, employee_id: "EMP101")

      expect { post_employee }.not_to change(Employee, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "code")).to eq("validation_failed")
      expect(response.parsed_body.dig("error", "details")).to include(
        "Employee has already been taken"
      )
    end

    it "rejects a duplicate work email with field details" do
      create(:employee, work_email: "ravi@demo.test")

      expect { post_employee }.not_to change(Employee, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "details")).to include(
        "Work email has already been taken"
      )
    end

    it "rejects an empty component list" do
      expect do
        post_employee(payload.deep_merge(compensation: { components: [] }))
      end.not_to change(Employee, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]).to include(
        "code" => "validation_failed",
        "message" => "at least one compensation component is required",
        "details" => [ "at least one compensation component is required" ]
      )
    end

    it "denies a non-HR user without creating an employee" do
      employee_headers = authentication_headers(create(:user))

      expect { post_employee(payload, employee_headers) }
        .not_to change(Employee, :count)

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body.dig("error", "code")).to eq("forbidden")
    end

    it "rejects an unauthenticated create" do
      expect { post_employee(payload, {}) }.not_to change(Employee, :count)

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body.dig("error", "code")).to eq("invalid_token")
    end
  end
end
