module Employees
  class ImportSheet
    class MissingDefaultPassword < StandardError; end

    MANAGER_WARNING = "Warning: employee was imported without a manager; " \
      "correct manager_employee_id and upload this file with the update import to assign it".freeze

    def self.call(employee_import) = new(employee_import).call

    def initialize(employee_import)
      @employee_import = employee_import
    end

    def call
      password_digest = default_password_digest if employee_import.mode == "create"
      rows = employee_import.file.open { |file| SheetParser.call(file.path, mode: employee_import.mode) }
      result = employee_import.mode == "create" ? create_employees(rows, password_digest) : UpdateRows.call(rows)
      employee_import.update!(status: "completed", total_rows: rows.size, imported_rows: result.imported.size,
        row_errors: result.row_errors)
    rescue SheetParser::HeaderError, MissingDefaultPassword => e
      employee_import.update!(status: "failed", error_message: e.message)
    end

    private

    attr_reader :employee_import

    def create_employees(rows, password_digest)
      result = ImportRows.call(rows, password_digest:)
      manager_errors = MapManagers.call(result.imported).map { _1.merge("errors" => _1["errors"] + [ MANAGER_WARNING ]) }
      ImportRows::Result.new(imported: result.imported, row_errors: (result.row_errors + manager_errors).sort_by { _1["line"] })
    end

    # Hashed once and shared by every imported user; hashing per user would take minutes at 10,000 rows.
    def default_password_digest
      password = Rails.application.credentials.dig(:employee_import, :default_password)
      raise MissingDefaultPassword, "Default password for imported employees is not configured" if password.blank?

      BCrypt::Password.create(password)
    end
  end
end
