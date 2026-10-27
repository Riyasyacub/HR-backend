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
          "status" => "active", "department" => { "id" => sales.id, "name" => "Sales" },
          "manager" => nil
        },
        {
          "id" => ravi.id, "employee_id" => "EMP101", "first_name" => "Ravi",
          "last_name" => "Kumar", "work_email" => "ravi@demo.test", "country" => "India",
          "currency" => "INR", "job_title" => "Software Engineer", "start_date" => "2026-01-01",
          "status" => "active", "department" => { "id" => engineering.id, "name" => "Engineering" },
          "manager" => nil
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
          "manager" => nil,
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

    it "allows a manager to view an employee profile in their subtree (AC-04, TC-S04-05)" do
      manager_user = create(:user, email: "arjun@demo.test")
      arjun = create(:employee, user: manager_user)
      employee.update!(manager: arjun)

      get_employee(employee.id, authentication_headers(manager_user))

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "id")).to eq(employee.id)
      expect(response.parsed_body.dig("data", "first_name")).to eq("Ravi")
    end

    it "hides compensation and bank details from a manager (AC-06, R-05)" do
      manager_user = create(:user, email: "arjun@demo.test")
      arjun = create(:employee, user: manager_user)
      employee.update!(manager: arjun)

      get_employee(employee.id, authentication_headers(manager_user))

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"]).not_to have_key("bank")
      expect(response.parsed_body["data"]).not_to have_key("compensation")
    end

    it "denies a manager access to an employee outside their subtree (AC-04, TC-S04-05)" do
      manager_user = create(:user, email: "robert@demo.test")
      robert = create(:employee, user: manager_user)
      other_emp = create(:employee, manager: robert)

      get_employee(employee.id, authentication_headers(manager_user))

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
          "manager" => nil,
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

    it "creates an employee assigned to an existing manager" do
      manager = create(:employee, employee_id: "EMP100", work_email: "mgr@demo.test")

      post_employee(payload.deep_merge(employee: { manager_id: manager.id }))

      expect(response).to have_http_status(:created)
      expect(response.parsed_body.dig("data", "manager")).to eq(
        "id" => manager.id, "employee_id" => "EMP100", "name" => "#{manager.first_name} #{manager.last_name}"
      )
    end
  end

  describe "PATCH /api/v1/employees/:id" do
    let(:arjun) { create(:employee, employee_id: "EMP101", first_name: "Arjun", last_name: "Patel", work_email: "arjun@demo.test") }
    let(:priya) { create(:employee, employee_id: "EMP102", first_name: "Priya", last_name: "Sharma", work_email: "priya@demo.test") }
    let(:meera) { create(:employee, employee_id: "EMP103", first_name: "Meera", last_name: "Nair", work_email: "meera@demo.test") }

    def patch_employee(id, body, headers = hr_headers)
      patch "/api/v1/employees/#{id}", params: body, as: :json, headers:
    end

    it "allows HR to assign a manager to an employee (TC-S04-01)" do
      patch_employee(priya.id, { employee: { manager_id: arjun.id } })

      expect(response).to have_http_status(:ok)
      expect(priya.reload.manager).to eq(arjun)
      expect(response.parsed_body.dig("data", "manager")).to eq(
        "id" => arjun.id, "employee_id" => "EMP101", "name" => "Arjun Patel"
      )
    end

    it "allows HR to reassign a manager immediately (TC-S04-04)" do
      priya.update!(manager: arjun)
      arjun.update!(manager: meera)

      patch_employee(priya.id, { employee: { manager_id: meera.id } })

      expect(response).to have_http_status(:ok)
      expect(priya.reload.manager).to eq(meera)
      expect(response.parsed_body.dig("data", "manager", "name")).to eq("Meera Nair")
    end

    it "allows HR to remove a manager by setting manager_id to nil" do
      priya.update!(manager: arjun)

      patch_employee(priya.id, { employee: { manager_id: nil } })

      expect(response).to have_http_status(:ok)
      expect(priya.reload.manager).to be_nil
      expect(response.parsed_body.dig("data", "manager")).to be_nil
    end

    it "rejects setting an employee as their own manager with 422 (TC-S04-03)" do
      patch_employee(priya.id, { employee: { manager_id: priya.id } })

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "code")).to eq("validation_failed")
      expect(response.parsed_body.dig("error", "details")).to include("Manager cannot be yourself")
    end

    it "rejects reporting cycles with 422 (TC-S04-02)" do
      priya.update!(manager: arjun)

      patch_employee(arjun.id, { employee: { manager_id: priya.id } })

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "code")).to eq("validation_failed")
      expect(response.parsed_body.dig("error", "details")).to include("Manager creates a reporting cycle")
    end

    it "rejects assigning a non-existent manager with 422 (AC-01)" do
      patch_employee(priya.id, { employee: { manager_id: 999_999 } })

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "code")).to eq("validation_failed")
      expect(response.parsed_body.dig("error", "details")).to include("Manager must exist")
    end

    it "rejects updates by a manager or standard employee with 403 (AC-06, TC-S04-07)" do
      priya.update!(manager: arjun)
      manager_user = create(:user, email: "arjun@demo.test")
      arjun.update!(user: manager_user)
      manager_headers = authentication_headers(manager_user)

      patch_employee(priya.id, { employee: { job_title: "Staff Engineer" } }, manager_headers)

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body.dig("error", "code")).to eq("forbidden")
    end

    it "rejects unauthenticated updates" do
      patch_employee(priya.id, { employee: { manager_id: arjun.id } }, {})

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body.dig("error", "code")).to eq("invalid_token")
    end
  end

  describe "GET /api/v1/employees/team" do
    def get_team(headers = hr_headers)
      get "/api/v1/employees/team", headers:
    end

    it "returns the manager's subtree employees (AC-04)" do
      manager_user = create(:user, email: "arjun@demo.test")
      arjun = create(:employee, employee_id: "EMP101", first_name: "Arjun", user: manager_user)
      priya = create(:employee, employee_id: "EMP102", first_name: "Priya", manager: arjun)
      kavita = create(:employee, employee_id: "EMP104", first_name: "Kavita", manager: priya)
      create(:employee, employee_id: "EMP103", first_name: "John")

      get_team(authentication_headers(manager_user))

      expect(response).to have_http_status(:ok)
      ids = response.parsed_body["data"].map { |e| e["employee_id"] }
      expect(ids).to match_array(%w[EMP102 EMP104])
      expect(ids).not_to include("EMP103")
      expect(response.parsed_body["data"].first).not_to have_key("bank")
    end

    it "denies access to a user with no direct reports (AC-05, TC-S04-06)" do
      emp_user = create(:user, email: "priya@demo.test")
      create(:employee, user: emp_user)

      get_team(authentication_headers(emp_user))

      expect(response).to have_http_status(:forbidden)
    end

    it "denies access to unauthenticated requests" do
      get_team({})

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
