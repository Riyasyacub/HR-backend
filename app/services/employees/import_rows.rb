module Employees
  class ImportRows
    BATCH_SIZE = 1000
    Imported = Data.define(:row, :employee)
    Result = Data.define(:imported, :row_errors)

    def self.call(rows, password_digest:) = new(password_digest:).call(rows)

    def initialize(password_digest:)
      @password_digest = password_digest
      @row_errors = []
    end

    def call(rows)
      importable = reject_existing(rows.reject { |row| row.errors.any? && record_error(row, row.errors) })
      imported = importable.each_slice(BATCH_SIZE).flat_map { |batch| Employee.transaction { import_batch(batch) } }
      Result.new(imported:, row_errors: @row_errors.sort_by { _1["line"] })
    end

    private

    def record_error(row, errors) = @row_errors << { "line" => row.line, "errors" => errors }

    def reject_existing(rows)
      ids = Employee.where(employee_id: rows.map { normalized(:employee_id, _1) }).pluck(:employee_id).to_set
      emails = Employee.where(work_email: rows.map { normalized(:work_email, _1) }).pluck(:work_email).to_set
      rows.reject do |row|
        errors = []
        errors << "employee_id #{normalized(:employee_id, row)} already exists" if ids.include?(normalized(:employee_id, row))
        errors << "work_email #{normalized(:work_email, row)} already exists" if emails.include?(normalized(:work_email, row))
        errors.any? && record_error(row, errors)
      end
    end

    def normalized(field, row) = Employee.normalize_value_for(field, row.attributes[field].to_s)

    def import_batch(rows)
      pairs = rows.map { |row| Imported.new(row:, employee: Employee.new(row.attributes)) }
      failed = Employee.import(pairs.map(&:employee), validate: true).failed_instances.to_set
      pairs.reject { |pair| failed.include?(pair.employee) && record_error(pair.row, pair.employee.errors.full_messages) }
        .tap do |imported|
          link_users(imported.map(&:employee))
          ImportCompensation.call(imported)
          Leaves::GrantEntitlements.grant_all(employee_ids: imported.map { _1.employee.id }, year: Date.current.year)
        end
    end

    def link_users(employees)
      users = User.where(email: employees.map(&:work_email)).index_by(&:email)
      new_users = employees.reject { users.key?(_1.work_email) }.map do |employee|
        User.new(name: "#{employee.first_name} #{employee.last_name}", email: employee.work_email, country: employee.country,
          role: standard_role, password_digest: @password_digest, active: true)
      end
      User.import(new_users, validate: false)
      new_users.each { users[_1.email] = _1 }
      employees.each { _1.user_id = users.fetch(_1.work_email).id }
      Employee.import(employees, on_duplicate_key_update: { conflict_target: [ :id ], columns: [ :user_id ] }, validate: false)
    end

    def standard_role = @standard_role ||= Role.find_or_create_by!(name: Role::STANDARD_EMPLOYEE)
  end
end
