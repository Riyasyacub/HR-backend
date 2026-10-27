module Employees
  class UpdateRows
    def self.call(rows) = new.call(rows)

    def call(rows)
      @row_errors = []
      known = known_employees(rows.reject { |row| row.errors.any? && record_error(row, row.errors) })
      appendable = reject_existing_compensation(known.select { _1.row.components.any? })
      Employee.transaction do
        appendable.group_by { effective_date(_1) }.each { |date, pairs| ImportCompensation.call(pairs, effective_date: date) }
      end
      rejected_lines = @row_errors.map { _1["line"] }.to_set
      applied = known.reject { rejected_lines.include?(_1.row.line) }
      ImportRows::Result.new(imported: applied, row_errors: (@row_errors + MapManagers.call(applied)).sort_by { _1["line"] })
    end

    private

    def record_error(row, errors) = @row_errors << { "line" => row.line, "errors" => errors }

    def effective_date(pair) = pair.row.effective_date || Date.current

    def known_employees(rows)
      ids = rows.map { Employee.normalize_value_for(:employee_id, _1.attributes[:employee_id].to_s) }
      employees = Employee.where(employee_id: ids).index_by(&:employee_id)
      rows.zip(ids).filter_map do |row, id|
        next ImportRows::Imported.new(row:, employee: employees[id]) if employees[id]

        record_error(row, [ "unknown employee #{id}" ])
        nil
      end
    end

    def reject_existing_compensation(pairs)
      existing = Compensation.where(employee_id: pairs.map { _1.employee.id }, effective_date: pairs.map { effective_date(_1) }.uniq)
        .pluck(:employee_id, :effective_date).to_set
      pairs.reject do |pair|
        existing.include?([ pair.employee.id, effective_date(pair) ]) &&
          record_error(pair.row, [ "compensation already exists on #{effective_date(pair).iso8601}" ])
      end
    end
  end
end
