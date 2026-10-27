require "rails_helper"

RSpec.describe "Headcount report", type: :request do
  let(:hr_headers) { authentication_headers(create(:user, :hr)) }

  def headcount(params, headers = hr_headers)
    get("/api/v1/reports/headcount", params:, headers:)
  end

  it "groups active headcount by country with onboarding counted separately (BR-RPT-01)" do
    create_list(:employee, 2, country: "India")
    create(:employee, country: "India", status: "onboarding")
    create(:employee, country: "USA")

    headcount(group_by: "country")

    expect(response.parsed_body).to eq(
      "data" => [ { "group" => "India", "headcount" => 2, "onboarding" => 1 }, { "group" => "USA", "headcount" => 1, "onboarding" => 0 } ],
      "meta" => { "group_by" => "country", "headcount" => 3, "onboarding" => 1 }
    )
  end

  it "matches the employee list for the same country filter (TC-S10-01, AC-01)" do
    create_list(:employee, 3, country: "India")
    create(:employee, country: "Canada")

    headcount(group_by: "department", country: "India")
    report_total = response.parsed_body["meta"]["headcount"]
    get("/api/v1/employees", params: { country: "India", status: "active" }, headers: hr_headers)

    expect(report_total).to eq(response.parsed_body["meta"]["total"])
  end

  it "groups by department and by manager" do
    engineering = create(:department, name: "Engineering")
    meera = create(:employee, first_name: "Meera", last_name: "Nair", department: engineering)
    create(:employee, manager: meera, department: engineering)

    headcount(group_by: "department")
    expect(response.parsed_body["data"]).to eq([ { "group" => "Engineering", "headcount" => 2, "onboarding" => 0 } ])

    headcount(group_by: "manager")
    expect(response.parsed_body["data"].pluck("group", "headcount")).to eq([ [ "Meera Nair", 1 ], [ "No manager", 1 ] ])
  end

  it "shows a manager only their subtree (TC-S10-07, AC-06)" do
    arjun_user = create(:user)
    arjun = create(:employee, user: arjun_user, country: "India")
    create(:employee, manager: create(:employee, manager: arjun, country: "India"), country: "India")
    create(:employee, country: "USA")

    headcount({ group_by: "country" }, authentication_headers(arjun_user))

    expect(response.parsed_body["data"]).to eq([ { "group" => "India", "headcount" => 2, "onboarding" => 0 } ])
  end

  it "denies an employee without reports" do
    employee_user = create(:user)
    create(:employee, user: employee_user)

    headcount({ group_by: "country" }, authentication_headers(employee_user))

    expect(response).to have_http_status(:forbidden)
  end

  it "rejects an unknown grouping" do
    headcount(group_by: "salary")

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body["error"]["code"]).to eq("invalid_group_by")
  end
end
