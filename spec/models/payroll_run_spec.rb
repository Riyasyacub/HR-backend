require "rails_helper"

RSpec.describe PayrollRun, type: :model do
  it "normalises the month to its first day" do
    expect(build(:payroll_run, month: Date.new(2026, 11, 17)).month).to eq(Date.new(2026, 11, 1))
  end

  it "allows one run per month" do
    create(:payroll_run)
    duplicate = build(:payroll_run)

    expect(duplicate).not_to be_valid
    expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "rejects an unknown status" do
    expect(build(:payroll_run, status: "approved")).not_to be_valid
  end
end
