require "rails_helper"

RSpec.describe Payroll::GenerateLines do
  let(:run) { create(:payroll_run, month: Date.new(2026, 2, 1), calculation_status: "processing") }

  def employee_with_pay(**attributes)
    create(:employee, start_date: Date.new(2026, 1, 1), **attributes).tap do |employee|
      create(:compensation, employee:, components_attributes: [ { name: "Basic", annual_amount: 1_200_000 } ])
    end
  end

  it "builds a line per active employee who started by month end (AC-01, TC-S08-01)" do
    priya = employee_with_pay
    employee_with_pay(status: "onboarding")
    create(:employee, start_date: Date.new(2026, 3, 2))

    described_class.call(run)

    expect(run.payroll_lines.map(&:employee)).to eq([ priya ])
    expect(run.payroll_lines.first).to have_attributes(monthly_gross: 100_000, total: 100_000, working_days: 20)
  end

  it "replaces a draft's lines with fresh numbers on recalculation" do
    priya = employee_with_pay
    described_class.call(run)
    create(:leave_record, employee: priya, leave_type: create(:leave_type, :unpaid), leave_date: Date.new(2026, 2, 9))

    described_class.call(run)

    expect(run.payroll_lines.reload.map(&:unpaid_days)).to eq([ 1 ])
  end

  it "marks the calculation completed" do
    described_class.call(run)

    expect(run.reload.calculation_status).to eq("completed")
  end

  it "leaves a generated run untouched (BR-PAY-06)" do
    employee_with_pay
    run.update!(status: "generated")

    described_class.call(run)

    expect(run.payroll_lines.reload).to be_empty
  end
end
