require "rails_helper"

RSpec.describe Assistant::ScopedSchema do
  let!(:meera) { create(:employee, user: create(:user), start_date: Date.new(2026, 1, 1)) }
  let!(:arjun) { create(:employee, user: create(:user), manager: meera, start_date: Date.new(2026, 1, 1)) }
  let!(:priya) { create(:employee, user: create(:user), manager: arjun, start_date: Date.new(2026, 1, 1)) }
  let!(:robert) { create(:employee, user: create(:user), start_date: Date.new(2026, 1, 1)) }
  let(:hr) { create(:user, :hr) }

  def run(schema, sql) = ActiveRecord::Base.connection.select_values("#{schema.cte_sql} #{sql}")

  it "gives HR every relation without bank or contact columns" do
    schema = described_class.new(hr)

    expect(schema.tier).to eq("hr")
    expect(schema.relations.keys).to contain_exactly("employees", "departments", "leave_types", "leave_records",
      "leave_ledger_entries", "compensations", "payroll_runs", "payroll_lines", "employee_top_managers", "leave_balances",
      "current_compensation", "payroll_summary")
    expect(schema.relations.values.flatten).not_to include("bank_name", "account_number", "ifsc", "phone", "personal_email", "address")
  end

  it "gives a manager no compensation or payroll relations" do
    schema = described_class.new(arjun.user)

    expect(schema.tier).to eq("manager")
    expect(schema.relations.keys).not_to include("compensations", "payroll_runs", "payroll_lines")
  end

  it "scopes employees to everyone for HR, the subtree for a manager and self for an employee (AC-02)" do
    expect(run(described_class.new(hr), "SELECT id FROM employees ORDER BY id")).to eq([ meera, arjun, priya, robert ].map(&:id))
    expect(run(described_class.new(arjun.user), "SELECT id FROM employees ORDER BY id")).to eq([ arjun.id, priya.id ])
    employee_schema = described_class.new(priya.user)
    expect(employee_schema.tier).to eq("employee")
    expect(run(employee_schema, "SELECT id FROM employees")).to eq([ priya.id ])
  end

  it "limits leave records and ledger entries to visible employees" do
    earned = create(:leave_type, name: "Earned")
    [ priya, robert ].each do |employee|
      record = create(:leave_record, employee:, leave_type: earned, leave_date: Date.new(2026, 10, 28))
      create(:leave_ledger_entry, employee:, leave_type: earned, leave_record: record, entry_type: "used", days: -1)
    end
    schema = described_class.new(arjun.user)

    expect(run(schema, "SELECT employee_id FROM leave_records")).to eq([ priya.id ])
    expect(run(schema, "SELECT employee_id FROM leave_ledger_entries")).to eq([ priya.id ])
  end

  it "describes each relation and its columns for the prompt" do
    prompt = described_class.new(arjun.user).prompt_schema

    expect(prompt).to include("employees(id, employee_id, first_name, last_name")
    expect(prompt).to include("leave_records(id, employee_id, leave_type_id, leave_date, reason)")
    expect(prompt).not_to include("payroll")
    expect(prompt).to include("manager_id -> employees.id (NULL for top-level managers: manager_id IS NULL)")
  end
end
