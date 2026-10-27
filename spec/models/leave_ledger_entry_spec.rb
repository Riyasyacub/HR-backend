require "rails_helper"

RSpec.describe LeaveLedgerEntry, type: :model do
  let(:employee) { create(:employee) }
  let(:earned) { create(:leave_type) }

  it "sums entries into a balance per employee, type and year" do
    create(:leave_ledger_entry, employee:, leave_type: earned, days: 6)
    create(:leave_ledger_entry, employee:, leave_type: earned, entry_type: "used", days: -2)
    create(:leave_ledger_entry, employee:, leave_type: earned, entry_type: "used", days: -1, year: 2025)

    expect(described_class.balance(employee:, leave_type: earned, year: 2026)).to eq(4)
  end

  it "cannot be changed once saved" do
    entry = create(:leave_ledger_entry)

    expect { entry.update!(days: 10) }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end

  it "allows only one entitlement per employee, type and year" do
    create(:leave_ledger_entry, employee:, leave_type: earned)
    duplicate = build(:leave_ledger_entry, employee:, leave_type: earned)

    expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "rejects an unknown entry type" do
    expect(build(:leave_ledger_entry, entry_type: "bonus")).not_to be_valid
  end

  it "summarises entitled, used and remaining per balanced type, counting reversals" do
    earned
    sick = create(:leave_type, name: "Sick")
    create(:leave_type, :unpaid)
    create(:leave_ledger_entry, employee:, leave_type: earned, days: 6)
    create(:leave_ledger_entry, employee:, leave_type: earned, entry_type: "used", days: -2)
    create(:leave_ledger_entry, employee:, leave_type: earned, entry_type: "reversal", days: 1)
    create(:leave_ledger_entry, employee:, leave_type: sick, days: 4, year: 2025)

    expect(described_class.summary(employee:, year: 2026)).to eq([
      { "leave_type" => "Earned", "entitled" => 6, "used" => 1, "remaining" => 5 },
      { "leave_type" => "Sick", "entitled" => 0, "used" => 0, "remaining" => 0 }
    ])
  end
end
