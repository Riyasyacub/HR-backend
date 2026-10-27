require "rails_helper"

RSpec.describe "Org chart", type: :request do
  let(:hr_headers) { authentication_headers(create(:user, :hr)) }
  let(:engineering) { create(:department, name: "Engineering") }
  let!(:meera) { create(:employee, employee_id: "EMP103", first_name: "Meera", last_name: "Nair", job_title: "Director", department: engineering) }
  let!(:arjun) { create(:employee, employee_id: "EMP102", first_name: "Arjun", last_name: "Rao", manager: meera) }
  let!(:priya) { create(:employee, employee_id: "EMP101", first_name: "Priya", last_name: "Sharma", manager: arjun) }
  let!(:robert) { create(:employee, employee_id: "EMP104", first_name: "Robert", last_name: "Miller", country: "USA") }

  def org_chart(params = {}, headers = hr_headers)
    get("/api/v1/org_chart", params:, headers:)
    response.parsed_body
  end

  it "starts HR at employees without a manager, with report counts and no pay data (AC-01, AC-06)" do
    data = org_chart["data"]

    expect(data.pluck("employee_id", "reports_count")).to eq([ [ "EMP103", 1 ], [ "EMP104", 0 ] ])
    expect(data.first).to eq("id" => meera.id, "employee_id" => "EMP103", "name" => "Meera Nair", "job_title" => "Director",
      "department" => "Engineering", "reports_count" => 1)
  end

  it "expands an employee to their direct reports only (AC-02)" do
    expect(org_chart(manager_id: meera.id)["data"].pluck("employee_id")).to eq(%w[EMP102])
  end

  it "starts a manager at themselves and lets them expand inside their subtree" do
    headers = authentication_headers(create(:user).tap { arjun.update!(user: _1) })

    expect(org_chart({}, headers)["data"].pluck("employee_id")).to eq(%w[EMP102])
    expect(org_chart({ manager_id: arjun.id }, headers)["data"].pluck("employee_id")).to eq(%w[EMP101])
  end

  it "hides employees outside a manager's subtree (AC-05)" do
    headers = authentication_headers(create(:user).tap { arjun.update!(user: _1) })

    org_chart({ manager_id: meera.id }, headers)
    expect(response).to have_http_status(:not_found)
    org_chart({ manager_id: robert.id }, headers)
    expect(response).to have_http_status(:not_found)
  end

  it "denies an employee without reports and returns 404 for an unknown manager" do
    org_chart({}, authentication_headers(create(:user).tap { priya.update!(user: _1) }))
    expect(response).to have_http_status(:forbidden)

    org_chart(manager_id: 0)
    expect(response).to have_http_status(:not_found)
  end

  it "uses the same number of queries however many reports there are (AC-07)" do
    count_queries = lambda do
      queries = 0
      callback = ->(*, payload) { queries += 1 unless payload[:name] == "SCHEMA" }
      headers = hr_headers
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { org_chart({ manager_id: meera.id }, headers) }
      queries
    end
    baseline = count_queries.call
    4.times { |number| create(:employee, employee_id: "EMP90#{number}", manager: meera, department: create(:department)) }

    expect(count_queries.call).to eq(baseline)
  end

  describe "GET /api/v1/org_chart/path" do
    def path(employee_id, headers = hr_headers)
      get("/api/v1/org_chart/path", params: { employee_id: }, headers:)
      response.parsed_body
    end

    it "returns the chain from the top level down to the employee (AC-03)" do
      expect(path(priya.id)["data"].pluck("employee_id", "reports_count")).to eq([ [ "EMP103", 1 ], [ "EMP102", 1 ], [ "EMP101", 0 ] ])
    end

    it "starts a manager's path at themselves and hides employees outside their subtree (AC-05)" do
      headers = authentication_headers(create(:user).tap { arjun.update!(user: _1) })

      expect(path(priya.id, headers)["data"].pluck("employee_id")).to eq(%w[EMP102 EMP101])
      path(robert.id, headers)
      expect(response).to have_http_status(:not_found)
      path(meera.id, headers)
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for an unknown employee and denies an employee without reports" do
      path(0)
      expect(response).to have_http_status(:not_found)

      path(priya.id, authentication_headers(create(:user).tap { priya.update!(user: _1) }))
      expect(response).to have_http_status(:forbidden)
    end

    it "uses the same number of queries however deep the employee is" do
      count_queries = lambda do |employee|
        queries = 0
        callback = ->(*, payload) { queries += 1 unless payload[:name] == "SCHEMA" }
        headers = hr_headers
        ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { path(employee.id, headers) }
        queries
      end
      deep = 3.times.reduce(priya) { |manager, number| create(:employee, employee_id: "EMP95#{number}", manager:) }

      expect(count_queries.call(deep)).to eq(count_queries.call(arjun))
    end
  end
end
