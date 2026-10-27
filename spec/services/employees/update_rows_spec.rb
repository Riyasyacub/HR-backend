require "rails_helper"

RSpec.describe Employees::UpdateRows do
  around { |example| travel_to(Date.new(2026, 10, 27)) { example.run } }

  def employee_with_pay(employee_id, **attributes)
    create(:employee, employee_id:, start_date: Date.new(2026, 1, 1), **attributes).tap do |employee|
      employee.compensations.create!(effective_date: Date.new(2026, 1, 1), components_attributes: [ { name: "Basic", annual_amount: 600_000 } ])
    end
  end

  def row(line, employee_id, amount: nil, manager: nil, effective_date: nil)
    components = amount ? [ { name: "Basic", annual_amount: amount } ] : []
    Employees::SheetParser::Row.new(line:, attributes: { employee_id: }, components:, manager_employee_id: manager, errors: [], effective_date:)
  end

  it "appends compensation on the row date, or today when blank, keeping history" do
    priya = employee_with_pay("EMP104")
    john = employee_with_pay("EMP106")

    result = described_class.call([ row(2, "emp104", amount: 700_000, effective_date: Date.new(2026, 11, 1)), row(3, "EMP106", amount: 650_000) ])

    expect(result.row_errors).to eq([])
    expect(result.imported.size).to eq(2)
    expect(priya.compensations.order(:effective_date).pluck(:annual_ctc)).to eq([ 600_000, 700_000 ])
    expect(john.compensations.order(:effective_date).last.effective_date).to eq(Date.new(2026, 10, 27))
  end

  it "assigns a missing manager and changes an existing one, without adding compensation for manager-only rows" do
    meera = employee_with_pay("EMP101")
    arjun = employee_with_pay("EMP103")
    priya = employee_with_pay("EMP104", manager: meera)

    described_class.call([ row(2, "EMP103", manager: "EMP101"), row(3, "EMP104", manager: "EMP103") ])

    expect(arjun.reload.manager).to eq(meera)
    expect(priya.reload.manager).to eq(arjun)
    expect(Compensation.count).to eq(3)
  end

  it "reports an unknown employee and a compensation that already exists on that date" do
    employee_with_pay("EMP104")

    result = described_class.call([ row(2, "EMP999", amount: 1), row(3, "EMP104", amount: 700_000, effective_date: Date.new(2026, 1, 1)) ])

    expect(result.row_errors).to eq([ { "line" => 2, "errors" => [ "unknown employee EMP999" ] },
      { "line" => 3, "errors" => [ "compensation already exists on 2026-01-01" ] } ])
    expect(result.imported).to eq([])
  end
end
