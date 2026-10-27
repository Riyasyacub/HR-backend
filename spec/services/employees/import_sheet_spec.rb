require "rails_helper"

RSpec.describe Employees::ImportSheet do
  let!(:department) { create(:department, name: "Engineering") }
  let(:header) do
    %w[employee_id first_name last_name work_email country department job_title start_date bank_name account_number
      manager_employee_id] + [ "Basic", "HRA", "Special Allowance" ]
  end

  def sheet_row(id, manager = nil, department_name = "Engineering")
    [ id, "First", id, "#{id.downcase}@demo.test", "India", department_name, "Engineer", Date.new(2026, 1, 5), "HDFC Bank", "1234",
      manager, 600_000, nil, nil ]
  end

  def employee_import(rows)
    file = build_xlsx(rows)
    create(:employee_import, status: "processing",
      file: Rack::Test::UploadedFile.new(file.path, EmployeeImport::XLSX_CONTENT_TYPE, original_filename: "employees.xlsx"))
  end

  def default_password(value)
    allow(Rails.application.credentials).to receive(:dig).and_call_original
    allow(Rails.application.credentials).to receive(:dig).with(:employee_import, :default_password).and_return(value)
  end

  it "imports employees, users and managers from the same file and saves the summary" do
    default_password("Import@1234")
    import = employee_import([ header, sheet_row("EMP103", "EMP101"), sheet_row("EMP101"), sheet_row("EMP105", nil, "Sales"),
      sheet_row("EMP104", "EMP999") ])

    described_class.call(import)

    expect(import.reload).to have_attributes(status: "completed", total_rows: 4, imported_rows: 3)
    expect(import.row_errors).to eq([ { "line" => 4, "errors" => [ "unknown department Sales" ] },
      { "line" => 5, "errors" => [ "unknown manager EMP999", described_class::MANAGER_WARNING ] } ])
    expect(described_class::MANAGER_WARNING).to eq("Warning: employee was imported without a manager; " \
      "correct manager_employee_id and upload this file with the update import to assign it")
    expect(Employee.find_by!(employee_id: "EMP103").manager.employee_id).to eq("EMP101")
    expect(User.find_by!(email: "emp101@demo.test").authenticate("Import@1234")).to be_truthy
  end

  it "fails with the header error" do
    default_password("Import@1234")
    import = employee_import([ %w[employee_id], [ "EMP101" ] ])

    described_class.call(import)

    expect(import.reload).to have_attributes(status: "failed", error_message: start_with("Missing columns:"))
  end

  it "fails without creating employees when the default password is not configured" do
    default_password(nil)
    import = employee_import([ header, sheet_row("EMP101") ])

    described_class.call(import)

    expect(import.reload).to have_attributes(status: "failed", error_message: "Default password for imported employees is not configured")
    expect(Employee.count).to eq(0)
  end

  it "runs an update import without the default password and saves its summary" do
    default_password(nil)
    create(:employee, employee_id: "EMP101")
    create(:employee, employee_id: "EMP103")
    import = employee_import([ %w[employee_id manager_employee_id], %w[EMP103 EMP101], %w[EMP555 EMP101] ])
    import.update!(mode: "update")

    described_class.call(import)

    expect(import.reload).to have_attributes(status: "completed", total_rows: 2, imported_rows: 1,
      row_errors: [ { "line" => 3, "errors" => [ "unknown employee EMP555" ] } ])
    expect(Employee.find_by!(employee_id: "EMP103").manager.employee_id).to eq("EMP101")
  end
end
