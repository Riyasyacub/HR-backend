module Payroll
  class ExportSheet
    HEADERS = [ "Employee ID", "Name", "Country", "Currency", "Bank name", "IFSC", "Account number",
      "Monthly gross", "Unpaid leave deduction", "Total", "Pay period" ].freeze
    COLUMNS = %i[employee_code employee_name country currency bank_name ifsc account_number
      monthly_gross unpaid_deduction total].freeze

    def self.to_xlsx(run)
      package = Axlsx::Package.new
      package.workbook.add_worksheet(name: "Payroll") do |sheet|
        amount = sheet.styles.add_style(format_code: "0.00")
        sheet.add_row HEADERS
        run.payroll_lines.order(:employee_code).pluck(*COLUMNS).each do |values|
          sheet.add_row [ *values, run.month.strftime("%Y-%m") ], types: [ *Array.new(7, :string), nil, nil, nil, :string ],
            style: [ *Array.new(7), amount, amount, amount, nil ]
        end
      end
      package.to_stream.read
    end
  end
end
