module Assistant
  # Business views built only from the asker's scoped CTEs, so they never widen visibility.
  module SemanticViews
    View = Data.define(:columns, :depends_on, :sql, :note)

    SHARED = {
      "employee_top_managers" => View.new(
        columns: %i[employee_id top_manager_id depth], depends_on: %w[employees],
        # Recursive under its own name: the outer CTE list must stay non-recursive because "employees" shadows the table.
        sql: "WITH RECURSIVE tree(employee_id, top_manager_id, depth) AS (SELECT e.id, e.id, 0 FROM employees e " \
             "WHERE NOT EXISTS (SELECT 1 FROM employees m WHERE m.id = e.manager_id) " \
             "UNION ALL SELECT r.id, t.top_manager_id, t.depth + 1 FROM employees r JOIN tree t ON r.manager_id = t.employee_id) SELECT * FROM tree",
        note: "every employee with their top-level manager; join on employee_id to roll anything up by top-level manager"),
      "leave_balances" => View.new(
        columns: %i[employee_id leave_type_id year entitled used remaining], depends_on: %w[leave_ledger_entries],
        sql: "SELECT employee_id, leave_type_id, year, sum(days) FILTER (WHERE entry_type = 'entitlement'), " \
             "-sum(days) FILTER (WHERE entry_type <> 'entitlement'), sum(days) FROM leave_ledger_entries GROUP BY 1, 2, 3",
        note: "leave days per employee, type and year")
    }.freeze

    HR = {
      "current_compensation" => View.new(
        columns: %i[employee_id effective_date annual_ctc currency], depends_on: %w[compensations],
        sql: "SELECT DISTINCT ON (employee_id) employee_id, effective_date, annual_ctc, currency FROM compensations " \
             "ORDER BY employee_id, effective_date DESC",
        note: "each employee's current annual CTC"),
      "payroll_summary" => View.new(
        columns: %i[employee_id month run_status currency monthly_gross unpaid_deduction total], depends_on: %w[payroll_lines payroll_runs],
        sql: "SELECT l.employee_id, r.month, r.status, l.currency, l.monthly_gross, l.unpaid_deduction, l.total " \
             "FROM payroll_lines l JOIN payroll_runs r ON r.id = l.payroll_run_id",
        note: "payout per employee and payroll month (first day of month); run_status draft, generated or paid; never add different currencies")
    }.freeze
  end
end
