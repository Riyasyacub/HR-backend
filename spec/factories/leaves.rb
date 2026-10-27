FactoryBot.define do
  factory :leave_record do
    employee { association :employee, start_date: Date.new(2026, 1, 1) }
    leave_type
    leave_date { Date.new(2026, 10, 28) }
    reason { "Family function" }
  end

  factory :leave_ledger_entry do
    employee
    leave_type
    year { 2026 }
    entry_type { "entitlement" }
    days { 6 }
  end

  factory :leave_import do
    association :uploaded_by, factory: %i[user hr]
    file do
      sheet = Object.new.extend(XlsxBuilder).build_xlsx([ %w[employee_id leave_date leave_type] ])
      Rack::Test::UploadedFile.new(sheet.path, LeaveImport::XLSX_CONTENT_TYPE, original_filename: "leave.xlsx")
    end
  end
end

FactoryBot.define do
  factory :payroll_run do
    month { Date.new(2026, 11, 1) }
    association :created_by, factory: %i[user hr]
  end

  factory :payroll_line do
    payroll_run
    employee
    country { "India" }
    currency { "INR" }
    monthly_gross { 100_000 }
    working_days { 21 }
    total { 100_000 }
  end
end
