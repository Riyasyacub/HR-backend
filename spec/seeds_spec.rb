require "rails_helper"

RSpec.describe "Demo seeds" do
  it "creates the eight demo accounts idempotently with hashed passwords" do
    expect { load Rails.root.join("db/seeds.rb") }.to change(User, :count).by(8)
    expect { load Rails.root.join("db/seeds.rb") }.not_to change(User, :count)

    expect(Role.order(:name).pluck(:name)).to eq([ Role::HR, Role::STANDARD_EMPLOYEE ])

    hr = User.find_by!(email: "hr@demo.test")
    priya = User.find_by!(email: "priya@demo.test")

    expect(hr).to be_hr
    expect(priya.role.name).to eq(Role::STANDARD_EMPLOYEE)
    expect(priya.authenticate("Demo@1234")).to eq(priya)
  end

  it "creates the four leave types idempotently with default entitlements" do
    expect { load Rails.root.join("db/seeds.rb") }.to change(LeaveType, :count).by(4)
    expect { load Rails.root.join("db/seeds.rb") }.not_to change(LeaveType, :count)

    expect(LeaveType.ordered.map(&:name)).to eq(LeaveType::NAMES)
    expect(LeaveType.find_by!(name: "Earned").default_entitlement).to eq(6)
    expect(LeaveType.find_by!(name: "Sick").default_entitlement).to eq(6)
    expect(LeaveType.find_by!(name: "Casual").default_entitlement).to eq(6)
    expect(LeaveType.find_by!(name: "Unpaid").default_entitlement).to be_nil
  end
end
