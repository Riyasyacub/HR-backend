module Assistant
  # The model only ever sees these virtual relations; each is a CTE over the asker's visible rows and allowed columns.
  class ScopedSchema
    SHARED_COLUMNS = {
      "employees" => %i[id employee_id first_name last_name work_email country currency job_title start_date status department_id manager_id],
      "departments" => %i[id name code active],
      "leave_types" => %i[id name default_entitlement],
      "leave_records" => %i[id employee_id leave_type_id leave_date reason],
      "leave_ledger_entries" => %i[employee_id leave_type_id year entry_type days]
    }.freeze
    HR_COLUMNS = {
      "compensations" => %i[employee_id effective_date annual_ctc currency],
      "payroll_runs" => %i[id month status paid_on],
      "payroll_lines" => %i[payroll_run_id employee_id country currency monthly_gross working_days unpaid_days unpaid_deduction total]
    }.freeze

    NOTES = {
      "employees" => "manager_id -> employees.id (NULL for top-level managers: manager_id IS NULL); department_id -> departments.id; status active or onboarding",
      "leave_types" => "name is Earned, Sick, Casual or Unpaid; default_entitlement is days per year",
      "leave_records" => "one row per leave day taken; employee_id -> employees.id; leave_type_id -> leave_types.id",
      "leave_ledger_entries" => "entry_type entitlement (+days), used (-days) or reversal; balance = sum(days) per employee, type and year",
      "compensations" => "annual_ctc in currency; the row with the latest effective_date is current",
      "payroll_runs" => "month is the first day of the payroll month; status draft, generated or paid",
      "payroll_lines" => "payroll_run_id -> payroll_runs.id; employee_id -> employees.id; total is the payout; never add different currencies"
    }.freeze

    def initialize(user)
      @user = user
      @employees = AssistantPolicy::Scope.new(user, Employee).resolve
    end

    def tier = @user.hr? ? "hr" : (@user.manager? ? "manager" : "employee")

    def relations = (@user.hr? ? SHARED_COLUMNS.merge(HR_COLUMNS) : SHARED_COLUMNS).merge(views.transform_values(&:columns))

    def cte_sql(only: relations.keys)
      needed = only + only.flat_map { views[_1]&.depends_on || [] }
      selected = relations.select { |name, _| needed.include?(name) }
      return "" if selected.empty?

      "WITH #{selected.map { |name, columns| "#{name}#{view_columns(name)} AS (#{definition(name, columns)})" }.join(', ')}"
    end

    def prompt_schema
      relations.map { |name, columns| [ "#{name}(#{columns.join(', ')})", NOTES[name] || views[name]&.note ].compact.join(" -- ") }.join("\n")
    end

    private

    def views = @user.hr? ? SemanticViews::SHARED.merge(SemanticViews::HR) : SemanticViews::SHARED
    def view_columns(name) = views[name] ? "(#{views[name].columns.join(', ')})" : ""
    def definition(name, columns) = views[name]&.sql || base_relation(name).select(*columns).to_sql

    def base_relation(name)
      { "employees" => @employees, "departments" => Department.all, "leave_types" => LeaveType.all,
        "leave_records" => LeaveRecord.where(employee_id: @employees.select(:id)),
        "leave_ledger_entries" => LeaveLedgerEntry.where(employee_id: @employees.select(:id)),
        "compensations" => Compensation.all, "payroll_runs" => PayrollRun.all, "payroll_lines" => PayrollLine.all }.fetch(name)
    end
  end
end
