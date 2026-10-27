module Leaves
  class SheetParser
    class HeaderError < StandardError; end

    REQUIRED_HEADERS = %w[employee_id leave_date leave_type].freeze
    Row = Data.define(:line, :employee, :leave_type, :leave_date, :reason, :errors)

    def self.call(path) = new(path).rows

    def initialize(path)
      @sheet = Roo::Excelx.new(path.to_s).sheet(0)
    rescue Zip::Error, ArgumentError, Nokogiri::XML::SyntaxError
      raise HeaderError, "File is not a valid Excel (.xlsx) workbook"
    end

    def rows
      headers = @sheet.row(1).map { |header| header.to_s.strip.downcase }
      missing = REQUIRED_HEADERS - headers
      raise HeaderError, "Missing columns: #{missing.join(', ')}" if missing.any?

      records = (2..@sheet.last_row.to_i).filter_map do |line|
        values = headers.zip(@sheet.row(line)).to_h
        [ line, values ] if values.values.any?(&:present?)
      end
      employees = Employee.where(employee_id: records.map { |_, values| normalized_id(values) }).index_by(&:employee_id)
      leave_types = LeaveType.all.index_by { |leave_type| leave_type.name.downcase }
      records.map { |line, values| build_row(line, values, employees, leave_types) }
    end

    private

    def build_row(line, values, employees, leave_types)
      employee = employees[normalized_id(values)]
      leave_type = leave_types[values["leave_type"].to_s.strip.downcase]
      leave_date = parse_date(values["leave_date"])
      errors = []
      errors << "unknown employee #{values['employee_id']}" unless employee
      errors << "leave_date must be a date or YYYY-MM-DD" unless leave_date
      errors << "unknown leave type #{values['leave_type']}" unless leave_type
      Row.new(line:, employee:, leave_type:, leave_date:, reason: values["reason"].to_s.strip.presence, errors:)
    end

    def normalized_id(values) = values["employee_id"].to_s.strip.upcase

    def parse_date(value)
      return value.to_date if value.is_a?(Date)

      text = value.to_s.strip
      Date.strptime(text, "%Y-%m-%d") if text.match?(/\A\d{4}-\d{2}-\d{2}\z/)
    rescue Date::Error
      nil
    end
  end
end
