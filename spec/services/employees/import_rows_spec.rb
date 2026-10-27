require "rails_helper"

RSpec.describe Employees::ImportRows do
  let(:department) { create(:department) }
  let(:password_digest) { BCrypt::Password.create("Import@1234", cost: BCrypt::Engine::MIN_COST) }

  def row(line, employee_id, errors: [], **overrides)
    attributes = { employee_id:, first_name: "First#{line}", last_name: "Last", work_email: "#{employee_id.downcase}@demo.test",
      country: "India", department:, job_title: "Engineer", start_date: Date.new(2026, 1, 5), bank_name: "HDFC Bank",
      account_number: "1234", ifsc: nil, personal_email: nil, phone: nil, status: "active" }.merge(overrides)
    Employees::SheetParser::Row.new(line:, attributes:, components: [ { name: "Basic", annual_amount: 1_200_000 } ],
      manager_employee_id: nil, errors:)
  end

  def import(rows) = described_class.call(rows, password_digest:)

  it "imports valid rows as active employees with the currency from the country" do
    result = import([ row(2, "EMP501"), row(3, "EMP502", country: "USA") ])

    expect(result.row_errors).to eq([])
    expect(result.imported.map { |imported| imported.employee.employee_id }).to eq(%w[EMP501 EMP502])
    expect(Employee.order(:employee_id).pluck(:employee_id, :currency, :status)).to eq([ %w[EMP501 INR active], %w[EMP502 USD active] ])
  end

  it "creates a standard employee user with the shared password, or links an existing user with the same email" do
    existing = create(:user, email: "emp502@demo.test")

    import([ row(2, "EMP501"), row(3, "EMP502") ])

    created = Employee.find_by!(employee_id: "EMP501").user
    expect(created).to have_attributes(email: "emp501@demo.test", name: "First2 Last", country: "India", active: true)
    expect(created.role.name).to eq(Role::STANDARD_EMPLOYEE)
    expect(created.authenticate("Import@1234")).to be_truthy
    expect(Employee.find_by!(employee_id: "EMP502").user).to eq(existing)
  end

  it "skips rows with parser errors and reports them" do
    result = import([ row(2, "EMP501", errors: [ "unknown department Sales" ]), row(3, "EMP502") ])

    expect(result.row_errors).to eq([ { "line" => 2, "errors" => [ "unknown department Sales" ] } ])
    expect(Employee.pluck(:employee_id)).to eq(%w[EMP502])
  end

  it "rejects rows whose employee ID or work email already exists" do
    create(:employee, employee_id: "EMP501")
    create(:employee, work_email: "emp502@demo.test")

    result = import([ row(2, "emp501"), row(3, "EMP502"), row(4, "EMP503") ])

    expect(result.row_errors).to eq([ { "line" => 2, "errors" => [ "employee_id EMP501 already exists" ] },
      { "line" => 3, "errors" => [ "work_email emp502@demo.test already exists" ] } ])
    expect(result.imported.map { |imported| imported.employee.employee_id }).to eq(%w[EMP503])
  end

  it "reports model validation errors per row while other rows import" do
    result = import([ row(2, "EMP501", country: "Mars"), row(3, "EMP502") ])

    expect(result.row_errors.map { _1["line"] }).to eq([ 2 ])
    expect(result.row_errors.first["errors"]).to include("Country is not included in the list")
    expect(Employee.pluck(:employee_id)).to eq(%w[EMP502])
  end

  it "inserts employees in bulk" do
    inserts = []
    callback = ->(*, payload) { inserts << payload[:sql] if payload[:sql].start_with?('INSERT INTO "employees"') }
    rows = (1..20).map { |number| row(number + 1, "EMP#{600 + number}") }

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { import(rows) }

    expect(inserts.size).to be <= 2
    expect(Employee.count).to eq(20)
  end

  it "gives imported employees compensation and this year's entitlements with bulk inserts" do
    create(:leave_type, name: "Earned", default_entitlement: 6)
    inserts = []
    callback = ->(*, payload) { inserts << payload[:sql][/INSERT INTO "(\w+)"/, 1] if payload[:sql].start_with?("INSERT") }
    rows = (1..10).map { |number| row(number + 1, "EMP#{700 + number}") }

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { import(rows) }

    employee = Employee.find_by!(employee_id: "EMP701")
    expect(employee.compensations.sole.annual_ctc).to eq(1_200_000)
    expect(LeaveLedgerEntry.where(employee:, year: Date.current.year, entry_type: "entitlement").sum(:days)).to eq(6)
    expect(inserts.tally.slice("compensations", "compensation_components", "leave_ledger_entries").values).to all(eq(1))
  end
end
