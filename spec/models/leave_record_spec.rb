require "rails_helper"

RSpec.describe LeaveRecord, type: :model do
  it "is valid on a weekday within employment" do
    expect(build(:leave_record)).to be_valid
  end

  it "rejects a weekend date" do
    record = build(:leave_record, leave_date: Date.new(2026, 10, 31))

    expect(record).not_to be_valid
    expect(record.errors[:leave_date]).to include("must be a working day")
  end

  it "rejects a date before the employee's start date" do
    employee = create(:employee, start_date: Date.new(2026, 11, 2))
    record = build(:leave_record, employee:, leave_date: Date.new(2026, 10, 28))

    expect(record).not_to be_valid
    expect(record.errors[:leave_date]).to include("is before the employee's start date")
  end

  it "allows only one record per employee and date" do
    existing = create(:leave_record)
    duplicate = build(:leave_record, employee: existing.employee, leave_type: existing.leave_type,
      leave_date: existing.leave_date)

    expect(duplicate).not_to be_valid
    expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "flags unpaid leave for payroll deduction" do
    expect(build(:leave_record, leave_type: build(:leave_type, :unpaid))).to be_payroll_deduction
    expect(build(:leave_record)).not_to be_payroll_deduction
  end
end
