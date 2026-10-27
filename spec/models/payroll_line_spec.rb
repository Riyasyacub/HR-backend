require "rails_helper"

RSpec.describe PayrollLine, type: :model do
  it "allows one line per employee per run" do
    line = create(:payroll_line)
    duplicate = build(:payroll_line, payroll_run: line.payroll_run, employee: line.employee)

    expect(duplicate).not_to be_valid
    expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "requires currency and amounts" do
    line = build(:payroll_line, currency: nil, monthly_gross: nil, working_days: nil)

    expect(line).not_to be_valid
    expect(line.errors.attribute_names).to include(:currency, :monthly_gross, :working_days)
  end
end
