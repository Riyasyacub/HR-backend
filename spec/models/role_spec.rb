require "rails_helper"

RSpec.describe Role, type: :model do
  it "requires a unique name" do
    create(:user, :hr)

    duplicate = Role.new(name: Role::HR)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:name]).to include("has already been taken")
  end

  it "identifies the configured roles" do
    expect(Role.new(name: Role::HR)).to be_hr
    expect(Role.new(name: Role::STANDARD_EMPLOYEE)).to be_standard_employee
  end
end
