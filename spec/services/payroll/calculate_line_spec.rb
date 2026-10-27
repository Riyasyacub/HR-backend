require "rails_helper"

RSpec.describe Payroll::CalculateLine do
  let(:february) { Date.new(2026, 2, 1) }
  let(:employee) { create(:employee, start_date: Date.new(2026, 1, 1)) }
  let(:unpaid) { create(:leave_type, :unpaid) }

  def give_compensation(amount, effective_date = Date.new(2026, 1, 1))
    create(:compensation, employee:, effective_date:, components_attributes: [ { name: "Basic", annual_amount: amount } ])
  end

  def calculate(month = february) = described_class.call(employee:, month:)

  it "divides the component total by 12, rounded to two decimals (TC-S08-02)" do
    give_compensation(1_200_000)
    expect(calculate[:monthly_gross]).to eq(BigDecimal("100000.00"))
  end

  it "rounds the monthly gross to two decimals" do
    give_compensation(1_000_001)

    expect(calculate[:monthly_gross]).to eq(BigDecimal("83333.42"))
  end

  it "counts Monday to Friday working days in the month" do
    give_compensation(1_200_000)

    expect(calculate[:working_days]).to eq(20)
    expect(calculate(Date.new(2026, 11, 1))[:working_days]).to eq(21)
  end

  it "deducts unpaid leave as gross / working days x unpaid days (TC-S08-03)" do
    give_compensation(1_200_000)
    [ Date.new(2026, 2, 9), Date.new(2026, 2, 10) ].each { create(:leave_record, employee:, leave_type: unpaid, leave_date: _1) }

    expect(calculate).to include(unpaid_days: 2, unpaid_deduction: BigDecimal("10000.00"), total: BigDecimal("90000.00"))
  end

  it "ignores paid leave and unpaid leave outside the month" do
    give_compensation(1_200_000)
    create(:leave_record, employee:, leave_type: create(:leave_type), leave_date: Date.new(2026, 2, 9))
    create(:leave_record, employee:, leave_type: unpaid, leave_date: Date.new(2026, 3, 2))

    expect(calculate).to include(unpaid_days: 0, unpaid_deduction: 0, total: BigDecimal("100000.00"))
  end

  it "uses the compensation effective by month end" do
    give_compensation(1_200_000)
    give_compensation(2_400_000, Date.new(2026, 3, 1))

    expect(calculate[:monthly_gross]).to eq(BigDecimal("100000.00"))
  end

  it "lists missing components as a blocking issue with zero pay (TC-S08-06)" do
    expect(calculate).to include(monthly_gross: 0, total: 0, blocking_issues: [ "missing compensation components" ])
  end

  it "copies the employee's country and currency" do
    give_compensation(1_200_000)

    expect(calculate).to include(country: "India", currency: "INR", blocking_issues: [])
  end
end
