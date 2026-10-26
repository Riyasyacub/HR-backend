require "rails_helper"

RSpec.describe "Settings departments", type: :request do
  let(:hr_headers) { authentication_headers(create(:user, :hr)) }

  def get_departments(headers = hr_headers)
    get "/api/v1/settings/departments", headers:
  end

  def create_department(attributes, headers = hr_headers)
    post "/api/v1/settings/departments",
      params: { department: attributes }, as: :json, headers:
  end

  def rename_department(department, attributes, headers = hr_headers)
    patch "/api/v1/settings/departments/#{department.id}",
      params: { department: attributes }, as: :json, headers:
  end

  def deactivate_department(department, headers = hr_headers)
    patch "/api/v1/settings/departments/#{department.id}/deactivate", headers:
  end

  it "lists departments alphabetically for HR" do
    create(:department, name: "Sales", code: "SAL")
    create(:department, name: "Engineering", code: "ENG")

    get_departments

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq(
      "data" => [
        { "id" => Department.find_by!(name: "Engineering").id, "name" => "Engineering",
          "code" => "ENG", "active" => true },
        { "id" => Department.find_by!(name: "Sales").id, "name" => "Sales",
          "code" => "SAL", "active" => true }
      ],
      "meta" => { "page" => 1, "per_page" => 2, "total" => 2 }
    )
  end

  it "creates a department for HR" do
    expect do
      create_department(name: " Engineering ", code: "eng")
    end.to change(Department, :count).by(1)

    expect(response).to have_http_status(:created)
    expect(response.parsed_body).to eq(
      "data" => {
        "id" => Department.last.id,
        "name" => "Engineering",
        "code" => "ENG",
        "active" => true
      }
    )
  end

  it "rejects a duplicate name without creating another department" do
    create(:department, name: "Engineering", code: "ENG")

    expect do
      create_department(name: "engineering", code: "ENG2")
    end.not_to change(Department, :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body).to include(
      "error" => {
        "code" => "validation_failed",
        "message" => "Name has already been taken",
        "details" => [ "Name has already been taken" ]
      }
    )
  end

  it "denies an employee access to list and create departments" do
    employee_headers = authentication_headers(create(:user))

    get_departments(employee_headers)
    expect(response).to have_http_status(:forbidden)

    expect do
      create_department({ name: "Engineering", code: "ENG" }, employee_headers)
    end.not_to change(Department, :count)
    expect(response).to have_http_status(:forbidden)
  end

  it "renames a department for HR" do
    department = create(:department, name: "Engineering", code: "ENG")

    rename_department(department, name: " Product Engineering ")

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq(
      "data" => {
        "id" => department.id,
        "name" => "Product Engineering",
        "code" => "ENG",
        "active" => true
      }
    )
    expect(department.reload.name).to eq("Product Engineering")
  end

  it "rejects a duplicate rename without changing the department" do
    create(:department, name: "Engineering", code: "ENG")
    department = create(:department, name: "Sales", code: "SAL")

    rename_department(department, name: "engineering")

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body.dig("error", "code")).to eq("validation_failed")
    expect(department.reload.name).to eq("Sales")
  end

  it "deactivates a department without deleting it" do
    department = create(:department, name: "Engineering", code: "ENG")

    expect { deactivate_department(department) }
      .not_to change(Department, :count)

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("data", "active")).to be(false)
    expect(department.reload).not_to be_active
  end

  it "does not expose a delete route for departments" do
    department = create(:department)

    expect do
      Rails.application.routes.recognize_path(
        "/api/v1/settings/departments/#{department.id}", method: :delete
      )
    end.to raise_error(ActionController::RoutingError)
  end

  it "denies an employee access to rename and deactivate" do
    department = create(:department, name: "Engineering", code: "ENG")
    employee_headers = authentication_headers(create(:user))

    rename_department(department, { name: "Sales" }, employee_headers)
    expect(response).to have_http_status(:forbidden)

    deactivate_department(department, employee_headers)
    expect(response).to have_http_status(:forbidden)
    expect(department.reload.name).to eq("Engineering")
    expect(department).to be_active
  end

  it "rejects an unauthenticated request" do
    get_departments({})

    expect(response).to have_http_status(:unauthorized)
    expect(response.parsed_body.dig("error", "code")).to eq("invalid_token")
  end

  it "rejects an unauthenticated rename and deactivation" do
    department = create(:department, name: "Engineering", code: "ENG")

    rename_department(department, { name: "Sales" }, {})
    expect(response).to have_http_status(:unauthorized)

    deactivate_department(department, {})
    expect(response).to have_http_status(:unauthorized)
    expect(department.reload.name).to eq("Engineering")
    expect(department).to be_active
  end
end
