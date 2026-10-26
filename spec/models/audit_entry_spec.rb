require "rails_helper"

RSpec.describe AuditEntry, type: :model do
  it "records the actor, auditable record, action, and change set" do
    actor = create(:user, :hr)
    leave_type = create(:leave_type)
    audit = described_class.create!(
      actor:,
      auditable: leave_type,
      action: "update",
      change_set: { "default_entitlement" => { "from" => 12, "to" => 18 } }
    )

    expect(audit.actor).to eq(actor)
    expect(audit.auditable).to eq(leave_type)
    expect(audit.change_set).to eq(
      "default_entitlement" => { "from" => 12, "to" => 18 }
    )
  end

  it "requires an action" do
    audit = build(:audit_entry, action: "")

    expect(audit).not_to be_valid
    expect(audit.errors[:action]).to be_present
  end
end
