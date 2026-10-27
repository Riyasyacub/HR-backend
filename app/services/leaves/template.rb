module Leaves
  class Template
    HEADERS = %w[employee_id leave_date leave_type reason].freeze
    EXAMPLE_ROW = [ "EMP101", Date.new(2026, 10, 28), "earned", "Family function" ].freeze

    def self.to_xlsx
      package = Axlsx::Package.new
      package.workbook.add_worksheet(name: "Leave") do |sheet|
        date_style = sheet.styles.add_style(format_code: "yyyy-mm-dd")
        sheet.add_row HEADERS
        sheet.add_row EXAMPLE_ROW, style: [ nil, date_style, nil, nil ]
        sheet.add_data_validation("C2:C1000", type: :list, hideDropDown: false,
          formula1: "\"#{LeaveType.order(:id).pluck(:name).map(&:downcase).join(',')}\"")
      end
      package.to_stream.read
    end
  end
end
