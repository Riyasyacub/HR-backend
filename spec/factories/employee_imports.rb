FactoryBot.define do
  factory :employee_import do
    association :uploaded_by, factory: %i[user hr]
    file do
      sheet = Object.new.extend(XlsxBuilder).build_xlsx([ %w[employee_id first_name] ])
      Rack::Test::UploadedFile.new(sheet.path, EmployeeImport::XLSX_CONTENT_TYPE, original_filename: "employees.xlsx")
    end
  end
end
