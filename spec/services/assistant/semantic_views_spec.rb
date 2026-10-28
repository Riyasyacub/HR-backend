require "rails_helper"

RSpec.describe Assistant::ScopedSchema, "semantic views" do
  let!(:meera) { create(:employee, user: create(:user), first_name: "Meera", start_date: Date.new(2026, 1, 1)) }
  let!(:arjun) { create(:employee, user: create(:user), manager: meera, first_name: "Arjun", start_date: Date.new(2026, 1, 1)) }
  let!(:priya) { create(:employee, manager: arjun, first_name: "Priya", start_date: Date.new(2026, 1, 1)) }
  let(:hr_schema) { described_class.new(create(:user, :hr)) }

  def rows(schema, sql, relations)
    Assistant::Executor.call(sql, schema:, relations:).rows
  end

  it "maps every employee to their top-level manager and depth for HR" do
    result = rows(hr_schema, "SELECT employee_id, top_manager_id, depth FROM employee_top_managers ORDER BY depth", %w[employee_top_managers])

    expect(result).to eq([ [ meera.id, meera.id, 0 ], [ arjun.id, meera.id, 1 ], [ priya.id, meera.id, 2 ] ])
  end

  it "treats a manager as the top of their own visible tree" do
    result = rows(described_class.new(arjun.user), "SELECT employee_id, top_manager_id FROM employee_top_managers ORDER BY employee_id",
      %w[employee_top_managers])

    expect(result).to eq([ [ arjun.id, arjun.id ], [ priya.id, arjun.id ] ])
  end

  it "summarises leave balances from the ledger" do
    earned = create(:leave_type, name: "Earned", default_entitlement: 6)
    create(:leave_ledger_entry, employee: priya, leave_type: earned, year: 2026, days: 6)
    create(:leave_ledger_entry, employee: priya, leave_type: earned, year: 2026, entry_type: "used", days: -2)

    expect(rows(hr_schema, "SELECT employee_id, year, entitled, used, remaining FROM leave_balances", %w[leave_balances]))
      .to eq([ [ priya.id, 2026, 6, 2, 4 ] ])
  end

  it "keeps only the latest compensation per employee, for HR only" do
    priya.compensations.create!(effective_date: Date.new(2026, 1, 1), components_attributes: [ { name: "Basic", annual_amount: 600_000 } ])
    priya.compensations.create!(effective_date: Date.new(2026, 10, 1), components_attributes: [ { name: "Basic", annual_amount: 700_000 } ])

    expect(rows(hr_schema, "SELECT employee_id, annual_ctc FROM current_compensation", %w[current_compensation])).to eq([ [ priya.id, 700_000 ] ])
    expect(described_class.new(arjun.user).relations.keys).not_to include("current_compensation", "payroll_summary")
  end

  it "summarises payroll per employee and month with the run status" do
    run = create(:payroll_run, month: Date.new(2026, 10, 1), status: "paid", paid_on: Date.new(2026, 10, 30), calculation_status: "completed")
    create(:payroll_line, payroll_run: run, employee: priya, total: 90_000)

    expect(rows(hr_schema, "SELECT employee_id, month, run_status, total FROM payroll_summary", %w[payroll_summary]))
      .to eq([ [ priya.id, Date.new(2026, 10, 1), "paid", 90_000 ] ])
  end

  it "adds the relations a view depends on, ahead of the view" do
    sql = hr_schema.cte_sql(only: %w[employee_top_managers])

    expect(sql).to start_with("WITH employees AS (")
    expect(sql).to include("employee_top_managers(employee_id, top_manager_id, depth) AS (")
  end

  it "rolls payroll up by top-level manager with a simple join" do
    run = create(:payroll_run, month: Date.new(2026, 10, 1), status: "paid", paid_on: Date.new(2026, 10, 30), calculation_status: "completed")
    create(:payroll_line, payroll_run: run, employee: priya, total: 90_000)
    create(:payroll_line, payroll_run: run, employee: arjun, total: 10_000)
    sql = <<~SQL
      SELECT t.top_manager_id, sum(p.total) FROM payroll_summary p JOIN employee_top_managers t ON t.employee_id = p.employee_id
      WHERE p.month = '2026-10-01' GROUP BY t.top_manager_id
    SQL
    relations = Assistant::SqlValidator.call(sql, allowed_relations: hr_schema.relations.keys)

    expect(rows(hr_schema, sql, relations)).to eq([ [ meera.id, 100_000 ] ])
  end
end
