require "rails_helper"

RSpec.describe EmployeeImport, type: :model do
  it "is valid with an attached Excel file" do
    expect(build(:employee_import)).to be_valid
  end

  it "requires an attached file" do
    employee_import = build(:employee_import, file: nil)

    expect(employee_import).not_to be_valid
    expect(employee_import.errors[:file]).to include("can't be blank")
  end

  it "rejects a file that is not an Excel workbook" do
    text = Rack::Test::UploadedFile.new(StringIO.new("a,b"), "text/csv", original_filename: "employees.csv")

    expect(build(:employee_import, file: text).tap(&:valid?).errors[:file]).to include("must be an Excel (.xlsx) file")
  end

  it "rejects a file larger than 10 MB" do
    employee_import = build(:employee_import)
    allow(employee_import.file.blob).to receive(:byte_size).and_return(10.megabytes + 1)

    expect(employee_import).not_to be_valid
    expect(employee_import.errors[:file]).to include("must be 10 MB or smaller")
  end

  it "rejects an unknown mode, also in the database" do
    expect(build(:employee_import, mode: "merge")).not_to be_valid
    expect { create(:employee_import).update_columns(mode: "merge") }
      .to raise_error(ActiveRecord::StatementInvalid, /employee_imports_mode_known/)
  end

  it "rejects an unknown status, also in the database" do
    expect(build(:employee_import, status: "paused")).not_to be_valid
    expect { create(:employee_import).update_columns(status: "paused") }
      .to raise_error(ActiveRecord::StatementInvalid, /employee_imports_status_known/)
  end
end
