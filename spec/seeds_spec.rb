require "rails_helper"

RSpec.describe "Demo seeds" do
  it "creates the eight demo accounts idempotently with hashed passwords" do
    expect { load Rails.root.join("db/seeds.rb") }.to change(User, :count).by(8)
    expect { load Rails.root.join("db/seeds.rb") }.not_to change(User, :count)

    expect(Role.order(:name).pluck(:name)).to eq([ Role::HR, Role::STANDARD_EMPLOYEE ])

    hr = User.find_by!(email: "hr@demo.test")
    priya = User.find_by!(email: "priya@demo.test")

    expect(hr).to be_hr
    expect(priya.role.name).to eq(Role::STANDARD_EMPLOYEE)
    expect(priya.authenticate("Demo@1234")).to eq(priya)
  end

  it "creates the four leave types idempotently with default entitlements" do
    expect { load Rails.root.join("db/seeds.rb") }.to change(LeaveType, :count).by(4)
    expect { load Rails.root.join("db/seeds.rb") }.not_to change(LeaveType, :count)

    expect(LeaveType.ordered.map(&:name)).to eq(LeaveType::NAMES)
    expect(LeaveType.find_by!(name: "Earned").default_entitlement).to eq(6)
    expect(LeaveType.find_by!(name: "Sick").default_entitlement).to eq(6)
    expect(LeaveType.find_by!(name: "Casual").default_entitlement).to eq(6)
    expect(LeaveType.find_by!(name: "Unpaid").default_entitlement).to be_nil
  end

  it "creates the demo workbook's five departments idempotently" do
    expect { load Rails.root.join("db/seeds.rb") }.to change(Department, :count).by(5)
    expect { load Rails.root.join("db/seeds.rb") }.not_to change(Department, :count)

    expect(Department.order(:code).pluck(:code, :name)).to eq([ %w[ENG Engineering], %w[FIN Finance], [ "HRM", "Human Resources" ],
      %w[OPS Operations], %w[SAL Sales] ])
  end

  it "prepares everything the demo employee workbook needs, so its upload imports with no row errors" do
    load Rails.root.join("db/seeds.rb")
    path = Rails.root.join("tmp/seeds_spec_workbook.xlsx")
    Demo::EmployeeWorkbook.write(path, size: 30)
    allow(Rails.application.credentials).to receive(:dig).and_call_original
    allow(Rails.application.credentials).to receive(:dig).with(:employee_import, :default_password).and_return("Import@1234")
    employee_import = create(:employee_import, status: "processing",
      file: Rack::Test::UploadedFile.new(path, EmployeeImport::XLSX_CONTENT_TYPE, original_filename: "employees.xlsx"))

    Employees::ImportSheet.call(employee_import)

    expect(employee_import.reload).to have_attributes(status: "completed", total_rows: 37, imported_rows: 37, row_errors: [])
    expect(User.find_by!(email: "priya@demo.test").employee.employee_id).to eq("EMP101")
  ensure
    FileUtils.rm_f(path)
  end
end
