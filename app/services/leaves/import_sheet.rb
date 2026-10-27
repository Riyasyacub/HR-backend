module Leaves
  class ImportSheet
    class RowRejected < StandardError; end

    def self.call(leave_import) = new(leave_import).call

    def initialize(leave_import)
      @leave_import = leave_import
    end

    def call
      leave_import.update!(status: "processing")
      rows = leave_import.file.open { |file| SheetParser.call(file.path) }
      row_errors = rows.filter_map { |row| import_row(row) }
      leave_import.update!(status: "completed", total_rows: rows.size,
        imported_rows: rows.size - row_errors.size, row_errors:)
    rescue SheetParser::HeaderError => e
      leave_import.update!(status: "failed", error_message: e.message)
    end

    private

    attr_reader :leave_import

    def import_row(row)
      return row_error(row, row.errors) if row.errors.any?

      row.employee.with_lock { save_record(row) }
      nil
    rescue RowRejected => e
      row_error(row, [ e.message ])
    rescue ActiveRecord::RecordInvalid => e
      row_error(row, e.record.errors.full_messages)
    end

    def row_error(row, errors) = { "line" => row.line, "errors" => errors }

    def save_record(row)
      record = LeaveRecord.find_or_initialize_by(employee: row.employee, leave_date: row.leave_date)
      previous_type = record.leave_type
      record.update!(leave_type: row.leave_type, reason: row.reason, leave_import:)
      return if previous_type == row.leave_type

      ledger_entry(record, previous_type, "reversal", 1) if previous_type&.default_entitlement
      charge(record) if row.leave_type.default_entitlement
    end

    def charge(record)
      if LeaveLedgerEntry.balance(employee: record.employee, leave_type: record.leave_type, year: record.leave_date.year) < 1
        raise RowRejected, "insufficient #{record.leave_type.name} balance"
      end

      ledger_entry(record, record.leave_type, "used", -1)
    end

    def ledger_entry(record, leave_type, entry_type, days)
      LeaveLedgerEntry.create!(employee: record.employee, leave_type:, leave_record: record,
        year: record.leave_date.year, entry_type:, days:)
    end
  end
end
