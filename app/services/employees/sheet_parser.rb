module Employees
  class SheetParser
    class HeaderError < StandardError; end

    REQUIRED_HEADERS = %w[employee_id first_name last_name work_email country department job_title start_date
      bank_name account_number].freeze
    TEXT_FIELDS = (REQUIRED_HEADERS - %w[department start_date] + %w[personal_email phone ifsc]).freeze
    COMPONENTS = { "basic" => "Basic", "hra" => "HRA", "special allowance" => "Special Allowance" }.freeze
    Row = Data.define(:line, :attributes, :components, :manager_employee_id, :errors, :effective_date) do
      def initialize(effective_date: nil, **attributes) = super
    end

    def self.call(path, mode: "create") = new(path, mode:).rows

    def initialize(path, mode: "create")
      @mode = mode
      @sheet = Roo::Excelx.new(path.to_s).sheet(0)
    rescue Zip::Error, ArgumentError, Nokogiri::XML::SyntaxError
      raise HeaderError, "File is not a valid Excel (.xlsx) workbook"
    end

    def rows
      headers = @sheet.row(1).map { |header| header.to_s.strip.downcase }
      missing = (@mode == "update" ? %w[employee_id] : REQUIRED_HEADERS + COMPONENTS.keys) - headers
      raise HeaderError, "Missing columns: #{missing.join(', ')}" if missing.any?

      departments = Department.all.flat_map { |department| [ [ department.name.downcase, department ], [ department.code.downcase, department ] ] }.to_h
      seen = { "employee_id" => Set.new, "work_email" => Set.new }
      (2..@sheet.last_row.to_i).filter_map do |line|
        values = headers.zip(@sheet.row(line)).to_h
        next unless values.values.any?(&:present?)

        @mode == "update" ? build_update_row(line, values, seen) : build_row(line, values, departments, seen)
      end
    end

    private

    def build_row(line, values, departments, seen)
      errors = []
      department = departments[text(values["department"]).downcase]
      start_date = parse_date(values["start_date"])
      components = component_amounts(values, errors)
      errors << "unknown department #{values['department']}" unless department
      errors << "start_date must be a date or YYYY-MM-DD" unless start_date
      errors << "at least one component amount is required" if components.empty?
      seen.each { |key, set| errors << "duplicate #{key} in file" unless set.add?(text(values[key]).downcase) }
      attributes = TEXT_FIELDS.to_h { |field| [ field.to_sym, text(values[field]).presence ] }
        .merge(department:, start_date:, status: "active")
      Row.new(line:, attributes:, components:, manager_employee_id: text(values["manager_employee_id"]).upcase.presence, errors:)
    end

    def build_update_row(line, values, seen)
      errors = []
      components = component_amounts(values, errors)
      effective_date = parse_date(values["effective_date"]) if values["effective_date"].present?
      errors << "effective_date must be a date or YYYY-MM-DD" if values["effective_date"].present? && !effective_date
      errors << "duplicate employee_id in file" unless seen["employee_id"].add?(text(values["employee_id"]).downcase)
      Row.new(line:, attributes: { employee_id: text(values["employee_id"]) }, components:, effective_date:,
        manager_employee_id: text(values["manager_employee_id"]).upcase.presence, errors:)
    end

    def component_amounts(values, errors)
      COMPONENTS.filter_map do |header, name|
        value = values[header]
        next if value.blank?

        amount = BigDecimal(text(value), exception: false)
        next { name:, annual_amount: amount } if amount&.positive?

        errors << "#{name} must be a positive amount"
        nil
      end
    end

    # Excel stores digit-only cells (account numbers, IDs) as floats; keep them as plain digit strings.
    def text(value) = value.is_a?(Float) && value == value.floor ? value.to_i.to_s : value.to_s.strip

    def parse_date(value)
      return value.to_date if value.is_a?(Date)

      text = value.to_s.strip
      Date.strptime(text, "%Y-%m-%d") if text.match?(/\A\d{4}-\d{2}-\d{2}\z/)
    rescue Date::Error
      nil
    end
  end
end
