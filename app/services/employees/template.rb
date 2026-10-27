module Employees
  class Template
    HEADERS = [ *SheetParser::REQUIRED_HEADERS, "manager_employee_id", "ifsc", "personal_email", "phone",
      *SheetParser::COMPONENTS.values ].freeze

    def self.to_xlsx
      example = [ "EMP900", "Asha", "Verma", "asha.verma@demo.test", "India", Department.order(:id).first&.name || "Engineering",
        "Software Engineer", Date.current.beginning_of_month, "HDFC Bank", "123456789012", nil, "HDFC0001234", nil, nil,
        900_000, 200_000, 100_000 ]
      package = Axlsx::Package.new
      package.workbook.add_worksheet(name: "Employees") do |sheet|
        sheet.add_row HEADERS
        sheet.add_row example, types: example.map { _1.is_a?(Numeric) ? :integer : (_1.is_a?(Date) ? :date : :string) }
      end
      package.to_stream.read
    end
  end
end
