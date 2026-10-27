require "rails_helper"

RSpec.describe Demo::EmployeeWorkbook do
  let(:rows) { described_class.rows(size: 60) }
  let(:by_id) { rows.index_by(&:first) }

  def manager_depth(employee_id)
    depth = 0
    depth += 1 while (employee_id = by_id.fetch(employee_id)[10])
    depth
  end

  it "has the template headers, the demo employees and prefixed seeded employees" do
    expect(described_class::HEADERS).to eq(Employees::Template::HEADERS)
    expect(rows.size).to eq(67)
    expect(rows.first(7).map(&:first)).to eq(%w[EMP101 EMP102 EMP103 EMP104 EMP105 EMP106 EMP107])
    expect(rows.drop(7)).to all(satisfy { |row| row[0].start_with?("SEED") && row[3].start_with?("seed") })
  end

  it "keeps the demo accounts' emails and hierarchy" do
    expect(by_id.slice("EMP101", "EMP102", "EMP103").transform_values { _1.values_at(3, 10) })
      .to eq("EMP101" => [ "priya@demo.test", "EMP102" ], "EMP102" => [ "arjun@demo.test", "EMP103" ], "EMP103" => [ "meera@demo.test", nil ])
  end

  it "spans three countries with a hierarchy at least three levels deep" do
    expect(rows.map { _1[4] }.tally.keys).to contain_exactly("India", "USA", "Canada")
    expect(rows.map { manager_depth(_1.first) }.max).to be >= 3
  end

  it "produces the same rows on every run" do
    expect(described_class.rows(size: 60)).to eq(rows)
  end

  it "writes a workbook the create import accepts without errors" do
    described_class.ensure_departments
    path = Rails.root.join("tmp/employee_workbook_spec.xlsx")
    described_class.write(path, size: 20)
    allow(Rails.application.credentials).to receive(:dig).and_call_original
    allow(Rails.application.credentials).to receive(:dig).with(:employee_import, :default_password).and_return("Import@1234")
    employee_import = create(:employee_import, status: "processing",
      file: Rack::Test::UploadedFile.new(path, EmployeeImport::XLSX_CONTENT_TYPE, original_filename: "employees.xlsx"))

    Employees::ImportSheet.call(employee_import)

    expect(employee_import.reload).to have_attributes(status: "completed", imported_rows: 27, row_errors: [])
  ensure
    FileUtils.rm_f(path)
  end
end
