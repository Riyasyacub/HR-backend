require "rails_helper"

RSpec.describe Demo::LeaveSeed do
  let(:today) { Date.new(2026, 10, 27) }
  let!(:tracked) { %w[Earned Sick Casual].map { |name| create(:leave_type, name:, default_entitlement: 2) } }
  let!(:unpaid) { create(:leave_type, :unpaid) }
  let!(:employees) { create_list(:employee, 30, start_date: Date.new(2026, 9, 1)) }

  def seed = described_class.call(today:)

  it "creates leave on weekdays in the last two months, never before the start date" do
    expect(seed).to be_positive

    dates = LeaveRecord.pluck(:leave_date)
    expect(dates).to all(be_between(Date.new(2026, 9, 1), today))
    expect(dates.none?(&:on_weekend?)).to be(true)
    expect(LeaveRecord.distinct.count(:employee_id)).to be_between(1, 29)
  end

  it "charges one used entry per tracked record and keeps every balance at or above zero (TC-S11-05)" do
    seed

    tracked_records = LeaveRecord.where(leave_type: tracked)
    expect(LeaveLedgerEntry.where(entry_type: "used").pluck(:leave_record_id)).to match_array(tracked_records.ids)
    expect(LeaveLedgerEntry.group(:employee_id, :leave_type_id, :year).sum(:days).values).to all(be >= 0)
    expect(LeaveLedgerEntry.where(leave_record: LeaveRecord.where(leave_type: unpaid))).to be_empty
  end

  it "grants missing entitlements before charging" do
    seed

    expect(LeaveLedgerEntry.where(entry_type: "entitlement", year: 2026).distinct.count(:employee_id)).to be_positive
  end

  it "creates nothing new when run again (TC-S11-06)" do
    seed

    expect { expect(seed).to eq(0) }.not_to change { [ LeaveRecord.count, LeaveLedgerEntry.count ] }
  end
end
