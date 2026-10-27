require "rails_helper"

RSpec.describe Employees::MapManagers do
  def imported(line, employee, manager_employee_id)
    row = Employees::SheetParser::Row.new(line:, attributes: {}, components: [], manager_employee_id:, errors: [])
    Employees::ImportRows::Imported.new(row:, employee:)
  end

  it "assigns managers from existing employees and from rows in the same file, in any order" do
    meera = create(:employee, employee_id: "EMP101")
    arjun = create(:employee, employee_id: "EMP103")
    priya = create(:employee, employee_id: "EMP104")

    errors = described_class.call([ imported(2, priya, "EMP103"), imported(3, arjun, "EMP101") ])

    expect(errors).to eq([])
    expect(priya.reload.manager).to eq(arjun)
    expect(arjun.reload.manager).to eq(meera)
  end

  it "reports an unknown manager and leaves the employee without one" do
    priya = create(:employee)

    expect(described_class.call([ imported(4, priya, "EMP999") ])).to eq([ { "line" => 4, "errors" => [ "unknown manager EMP999" ] } ])
    expect(priya.reload.manager).to be_nil
  end

  it "rejects an employee as their own manager" do
    priya = create(:employee, employee_id: "EMP104")

    expect(described_class.call([ imported(2, priya, "EMP104") ])).to eq([ { "line" => 2, "errors" => [ "employee cannot manage themselves" ] } ])
  end

  it "rejects the row that would close a reporting cycle" do
    first = create(:employee, employee_id: "EMP201")
    second = create(:employee, employee_id: "EMP202")

    errors = described_class.call([ imported(2, first, "EMP202"), imported(3, second, "EMP201") ])

    expect(errors).to eq([ { "line" => 3, "errors" => [ "manager EMP201 creates a reporting cycle" ] } ])
    expect(first.reload.manager).to eq(second)
    expect(second.reload.manager).to be_nil
  end

  it "updates once per distinct manager, not per employee" do
    manager = create(:employee, employee_id: "EMP101")
    reports = create_list(:employee, 5)
    updates = []
    callback = ->(*, payload) { updates << payload[:sql] if payload[:sql].start_with?('UPDATE "employees"') }

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      described_class.call(reports.each_with_index.map { |report, index| imported(index + 2, report, "EMP101") })
    end

    expect(updates.size).to eq(1)
    expect(Employee.where(manager:).count).to eq(5)
  end
end
