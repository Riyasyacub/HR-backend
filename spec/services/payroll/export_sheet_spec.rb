require "rails_helper"

RSpec.describe Payroll::ExportSheet do
  let(:run) { create(:payroll_run, status: "generated", month: Date.new(2026, 11, 1)) }

  def sheet
    file = Tempfile.new([ "payroll", ".xlsx" ]).tap { |f| f.binmode && f.write(described_class.to_xlsx(run)) && f.flush }
    Roo::Excelx.new(file.path).sheet(0)
  end

  def frozen_line(code, **attributes)
    create(:payroll_line, payroll_run: run, employee_code: code, employee_name: "Name #{code}", bank_name: "HDFC Bank",
      ifsc: "HDFC0001234", account_number: "123456789012", **attributes)
  end

  it "has the documented headers and one row per line with frozen details, amounts and pay period (AC-02, AC-03)" do
    frozen_line("EMP102", monthly_gross: 100_000, unpaid_deduction: 10_000, total: 90_000)

    expect(sheet.row(1)).to eq([ "Employee ID", "Name", "Country", "Currency", "Bank name", "IFSC", "Account number",
      "Monthly gross", "Unpaid leave deduction", "Total", "Pay period" ])
    expect(sheet.row(2)).to eq([ "EMP102", "Name EMP102", "India", "INR", "HDFC Bank", "HDFC0001234", "123456789012",
      100_000, 10_000, 90_000, "2026-11" ])
    expect(sheet.last_row).to eq(2)
  end

  it "orders rows by employee ID and uses the frozen bank details, not the live employee" do
    second = frozen_line("EMP105")
    frozen_line("EMP101")
    second.employee.update!(bank_name: "ICICI Bank")

    expect(sheet.column(1).drop(1)).to eq(%w[EMP101 EMP105])
    expect(sheet.column(5).drop(1)).to eq([ "HDFC Bank", "HDFC Bank" ])
  end
end
