require "rails_helper"

RSpec.describe Leaves::GrantEntitlements, ".grant_all" do
  it "grants each tracked type's default entitlement once and skips existing ones" do
    earned = create(:leave_type, name: "Earned", default_entitlement: 6)
    create(:leave_type, :unpaid)
    first, second = create_list(:employee, 2)
    create(:leave_ledger_entry, employee: first, leave_type: earned, year: 2026, days: 9)

    described_class.grant_all(employee_ids: [ first.id, second.id ], year: 2026)

    expect(LeaveLedgerEntry.where(entry_type: "entitlement").order(:employee_id).pluck(:employee_id, :days))
      .to eq([ [ first.id, 9 ], [ second.id, 6 ] ])
  end
end
