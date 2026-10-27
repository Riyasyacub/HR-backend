require "rails_helper"

RSpec.describe Leaves::GrantEntitlements do
  let!(:employee) { create(:employee) }
  let!(:earned) { create(:leave_type, name: "Earned", default_entitlement: 6) }
  let!(:sick) { create(:leave_type, name: "Sick", default_entitlement: 4) }

  def balance(leave_type) = LeaveLedgerEntry.balance(employee:, leave_type:, year: 2026)

  it "grants the default entitlement for each balanced leave type for the year" do
    described_class.call(employee:, year: 2026)

    expect([ balance(earned), balance(sick) ]).to eq([ 6, 4 ])
  end

  it "skips unpaid leave and types with a zero entitlement" do
    create(:leave_type, :unpaid)
    create(:leave_type, name: "Casual", default_entitlement: 0)

    described_class.call(employee:, year: 2026)

    expect(LeaveLedgerEntry.where(employee:).count).to eq(2)
  end

  it "grants only once when run twice" do
    2.times { described_class.call(employee:, year: 2026) }

    expect(balance(earned)).to eq(6)
  end

  it "backfills entitlements for every existing employee" do
    other = create(:employee)

    described_class.backfill(year: 2026)

    expect(LeaveLedgerEntry.where(employee: [ employee, other ], leave_type: earned).count).to eq(2)
  end
end
