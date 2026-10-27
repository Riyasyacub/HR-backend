module Reports
  class Leave
    def initialize(employees, year:)
      @employees = employees
      @year = year
      @tracked_types = LeaveType.where.not(default_entitlement: nil).order(:id).to_a
    end

    def rows(page_of_employees)
      ids = page_of_employees.map(&:id)
      ledger = ledger_for(ids).group(:employee_id, :leave_type_id, :entry_type).sum(:days)
        .group_by { |(employee_id, *), _| employee_id }
        .transform_values { |pairs| pairs.to_h { |(_, *key), days| [ key, days ] } }
      unpaid = unpaid_for(ids).group(:employee_id).count
      page_of_employees.map do |employee|
        { "id" => employee.id, "employee_id" => employee.employee_id, "name" => "#{employee.first_name} #{employee.last_name}",
          "balances" => LeaveLedgerEntry.balance_rows(ledger.fetch(employee.id, {}), @tracked_types),
          "unpaid_days" => unpaid.fetch(employee.id, 0) }
      end
    end

    def totals
      ids = @employees.select(:id)
      { "balances" => LeaveLedgerEntry.balance_rows(ledger_for(ids).group(:leave_type_id, :entry_type).sum(:days), @tracked_types),
        "unpaid_days" => unpaid_for(ids).count }
    end

    def export_headers
      [ "Employee ID", "Name", *@tracked_types.flat_map { |type| %w[entitled used remaining].map { "#{type.name} #{_1}" } }, "Unpaid days" ]
    end

    def export_rows(batch_size: 1000)
      batches = 0.step(by: batch_size).lazy.map { |offset| @employees.offset(offset).limit(batch_size).to_a }.take_while(&:any?)
      batches.flat_map { |batch| rows(batch).map { |row| export_row(row["employee_id"], row["name"], row) } }.to_a +
        [ export_row("Total", nil, totals) ]
    end

    private

    def export_row(code, name, row)
      [ code, name, *row["balances"].flat_map { _1.values_at("entitled", "used", "remaining") }, row["unpaid_days"] ]
    end

    def ledger_for(ids) = LeaveLedgerEntry.where(employee_id: ids, year: @year)

    def unpaid_for(ids)
      LeaveRecord.joins(:leave_type).where(employee_id: ids, leave_types: { name: "Unpaid" }, leave_date: Date.new(@year).all_year)
    end
  end
end
