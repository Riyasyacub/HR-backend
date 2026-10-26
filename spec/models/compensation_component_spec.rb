require "rails_helper"

RSpec.describe CompensationComponent, type: :model do
  subject(:component) { build(:compensation_component) }

  it { is_expected.to be_valid }

  it "requires a name and a positive annual amount" do
    component.assign_attributes(name: nil, annual_amount: 0)

    expect(component).not_to be_valid
    expect(component.errors[:name]).to be_present
    expect(component.errors[:annual_amount]).to be_present
  end

  it "requires unique component names per compensation, case-insensitively" do
    compensation = create(:compensation)
    create(:compensation_component, compensation:, name: "Basic")
    duplicate = build(:compensation_component, compensation:, name: "basic")

    expect(duplicate).not_to be_valid
  end

  it "allows the same component name across compensation revisions" do
    employee = create(:employee)
    first = create(:compensation, employee:)
    second = create(:compensation, employee:, effective_date: employee.start_date + 1.year)
    create(:compensation_component, compensation: first, name: "Basic")

    expect(build(:compensation_component, compensation: second, name: "Basic")).to be_valid
  end
end
