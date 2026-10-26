require "rails_helper"

RSpec.describe Employees::Create do
  let(:department) { create(:department) }
  let(:employee_attributes) do
    {
      employee_id: "EMP101",
      first_name: "Ravi",
      last_name: "Kumar",
      work_email: "ravi@demo.test",
      country: "India",
      department:,
      job_title: "Software Engineer",
      start_date: Date.new(2026, 1, 1),
      bank_name: "HDFC Bank",
      account_number: "123456789012",
      status: "active"
    }
  end
  let(:components) do
    [
      { name: "Basic", annual_amount: 1_000_000 },
      { name: "Allowance", annual_amount: 200_000 }
    ]
  end
  let(:compensation_attributes) { { components: } }

  def create_employee(employee_overrides: {}, compensation_overrides: {})
    described_class.call(
      employee_attributes: employee_attributes.merge(employee_overrides),
      compensation_attributes: compensation_attributes.merge(compensation_overrides)
    )
  end

  it "creates the employee, components, and derived annual CTC" do
    employee = create_employee

    expect(employee).to be_persisted
    expect(employee.currency).to eq("INR")

    compensation = employee.compensations.first
    expect(compensation.effective_date).to eq(employee.start_date)
    expect(compensation.annual_ctc).to eq(BigDecimal("1200000"))
    expect(compensation.components.pluck(:name)).to contain_exactly("Basic", "Allowance")
  end

  it "rejects an explicit annual CTC input" do
    expect do
      create_employee(compensation_overrides: { annual_ctc: 1_000_000 })
    end.to raise_error(Employees::Create::Invalid, "annual CTC is derived from components")

    expect(Employee.find_by(employee_id: "EMP101")).to be_nil
  end

  it "rejects an empty component list without creating an employee" do
    expect do
      create_employee(compensation_overrides: { components: [] })
    end.to raise_error(Employees::Create::Invalid, "at least one compensation component is required")

    expect(Employee.find_by(employee_id: "EMP101")).to be_nil
  end

  it "rolls back the employee when a component is invalid" do
    expect do
      create_employee(
        compensation_overrides: { components: [ { name: "Basic", annual_amount: 0 } ] }
      )
    end.to raise_error(ActiveRecord::RecordInvalid)

    expect(Employee.find_by(employee_id: "EMP101")).to be_nil
  end
end
