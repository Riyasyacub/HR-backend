require "rails_helper"

RSpec.describe LeaveType, type: :model do
  it "accepts non-negative integer entitlements for balanced types" do
    LeaveType::BALANCED_NAMES.each do |name|
      leave_type = build(:leave_type, name:, default_entitlement: 0)

      expect(leave_type).to be_valid
    end
  end

  it "rejects negative, missing, and non-integer entitlements" do
    [ -1, nil, 1.5 ].each do |entitlement|
      leave_type = build(:leave_type, default_entitlement: entitlement)

      expect(leave_type).not_to be_valid
      expect(leave_type.errors[:default_entitlement]).to be_present
    end
  end

  it "requires unpaid leave to have no entitlement" do
    unpaid = build(:leave_type, :unpaid, default_entitlement: 5)

    expect(unpaid).not_to be_valid
    expect(unpaid.errors[:default_entitlement]).to include("must be blank for unpaid leave")
  end

  it "rejects unknown leave-type names" do
    leave_type = build(:leave_type, name: "Maternity")

    expect(leave_type).not_to be_valid
    expect(leave_type.errors[:name]).to be_present
  end

  it "enforces non-negative entitlements in the database" do
    leave_type = build(:leave_type, default_entitlement: -1)

    expect { leave_type.save!(validate: false) }
      .to raise_error(ActiveRecord::StatementInvalid)
  end
end
