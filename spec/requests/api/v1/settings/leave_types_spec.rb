require "rails_helper"

RSpec.describe "Settings leave types", type: :request do
  def get_leave_types(headers)
    get "/api/v1/settings/leave_types", headers:
  end

  def update_leave_type(leave_type, attributes, headers)
    patch "/api/v1/settings/leave_types/#{leave_type.id}",
      params: { leave_type: attributes }, as: :json, headers:
  end

  def seed_leave_types
    [
      [ "Earned", 12 ],
      [ "Sick", 10 ],
      [ "Casual", 8 ],
      [ "Unpaid", nil ]
    ].each do |name, entitlement|
      create(:leave_type, name:, default_entitlement: entitlement)
    end
  end

  it "lists the four leave types in order for HR" do
    seed_leave_types

    get_leave_types(authentication_headers(create(:user, :hr)))

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq(
      "data" => [
        { "id" => LeaveType.find_by!(name: "Earned").id, "name" => "Earned",
          "default_entitlement" => 12, "balance_tracked" => true },
        { "id" => LeaveType.find_by!(name: "Sick").id, "name" => "Sick",
          "default_entitlement" => 10, "balance_tracked" => true },
        { "id" => LeaveType.find_by!(name: "Casual").id, "name" => "Casual",
          "default_entitlement" => 8, "balance_tracked" => true },
        { "id" => LeaveType.find_by!(name: "Unpaid").id, "name" => "Unpaid",
          "default_entitlement" => nil, "balance_tracked" => false }
      ],
      "meta" => { "page" => 1, "per_page" => 4, "total" => 4 }
    )
  end

  it "updates an entitlement and records an audit entry for HR" do
    seed_leave_types
    hr = create(:user, :hr)
    earned = LeaveType.find_by!(name: "Earned")

    expect do
      update_leave_type(earned, { default_entitlement: 18 }, authentication_headers(hr))
    end.to change(AuditEntry, :count).by(1)

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq(
      "data" => {
        "id" => earned.id,
        "name" => "Earned",
        "default_entitlement" => 18,
        "balance_tracked" => true
      }
    )

    audit = AuditEntry.last
    expect(audit.actor).to eq(hr)
    expect(audit.auditable).to eq(earned)
    expect(audit.action).to eq("update")
    expect(audit.change_set).to eq(
      "default_entitlement" => { "from" => 12, "to" => 18 }
    )
  end

  it "rejects a negative entitlement without changing or auditing it" do
    seed_leave_types
    earned = LeaveType.find_by!(name: "Earned")

    expect do
      update_leave_type(earned, { default_entitlement: -1 },
        authentication_headers(create(:user, :hr)))
    end.not_to change(AuditEntry, :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body.dig("error", "code")).to eq("validation_failed")
    expect(earned.reload.default_entitlement).to eq(12)
  end

  it "rejects an entitlement for unpaid leave" do
    seed_leave_types
    unpaid = LeaveType.find_by!(name: "Unpaid")

    expect do
      update_leave_type(unpaid, { default_entitlement: 5 },
        authentication_headers(create(:user, :hr)))
    end.not_to change(AuditEntry, :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(unpaid.reload.default_entitlement).to be_nil
  end

  it "does not audit an unchanged entitlement" do
    seed_leave_types
    earned = LeaveType.find_by!(name: "Earned")

    expect do
      update_leave_type(earned, { default_entitlement: 12 },
        authentication_headers(create(:user, :hr)))
    end.not_to change(AuditEntry, :count)

    expect(response).to have_http_status(:ok)
  end

  it "denies an employee access" do
    seed_leave_types
    earned = LeaveType.find_by!(name: "Earned")
    employee_headers = authentication_headers(create(:user))

    get_leave_types(employee_headers)
    expect(response).to have_http_status(:forbidden)

    expect do
      update_leave_type(earned, { default_entitlement: 18 }, employee_headers)
    end.not_to change(AuditEntry, :count)
    expect(response).to have_http_status(:forbidden)
  end

  it "rejects an unauthenticated update" do
    seed_leave_types
    earned = LeaveType.find_by!(name: "Earned")

    update_leave_type(earned, { default_entitlement: 18 }, {})

    expect(response).to have_http_status(:unauthorized)
    expect(earned.reload.default_entitlement).to eq(12)
  end

  it "rejects an unauthenticated request" do
    get_leave_types({})

    expect(response).to have_http_status(:unauthorized)
    expect(response.parsed_body.dig("error", "code")).to eq("invalid_token")
  end
end
