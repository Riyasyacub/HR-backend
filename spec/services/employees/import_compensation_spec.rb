require "rails_helper"

RSpec.describe Employees::ImportCompensation do
  let(:employee) { create(:employee, country: "USA", start_date: Date.new(2026, 2, 1)) }
  let(:components) { [ { name: "Basic", annual_amount: 90_000 }, { name: "HRA", annual_amount: 30_000 } ] }

  def imported(employee, components)
    row = Employees::SheetParser::Row.new(line: 2, attributes: {}, components:, manager_employee_id: nil, errors: [])
    Employees::ImportRows::Imported.new(row:, employee:)
  end

  it "creates a compensation effective from the start date with CTC equal to the component sum" do
    described_class.call([ imported(employee, components) ])

    compensation = employee.compensations.sole
    expect(compensation).to have_attributes(effective_date: Date.new(2026, 2, 1), annual_ctc: 120_000, currency: "USD")
    expect(compensation.components.order(:name).pluck(:name, :annual_amount)).to eq([ [ "Basic", 90_000 ], [ "HRA", 30_000 ] ])
  end

  it "appends a compensation on a given effective date and keeps the earlier one" do
    described_class.call([ imported(employee, components) ])

    described_class.call([ imported(employee, [ { name: "Basic", annual_amount: 100_000 } ]) ], effective_date: Date.new(2026, 10, 1))

    expect(employee.compensations.order(:effective_date).pluck(:effective_date, :annual_ctc))
      .to eq([ [ Date.new(2026, 2, 1), 120_000 ], [ Date.new(2026, 10, 1), 100_000 ] ])
  end
end
