require "rails_helper"

RSpec.describe LeaveImport, type: :model do
  it "is valid with an attached Excel file" do
    expect(build(:leave_import)).to be_valid
  end

  it "requires an attached file" do
    leave_import = build(:leave_import, file: nil)

    expect(leave_import).not_to be_valid
    expect(leave_import.errors[:file]).to include("can't be blank")
  end

  it "rejects a file that is not an Excel workbook" do
    text = Rack::Test::UploadedFile.new(StringIO.new("a,b"), "text/csv", original_filename: "leave.csv")
    leave_import = build(:leave_import, file: text)

    expect(leave_import).not_to be_valid
    expect(leave_import.errors[:file]).to include("must be an Excel (.xlsx) file")
  end

  it "rejects a file larger than 5 MB" do
    leave_import = build(:leave_import)
    allow(leave_import.file.blob).to receive(:byte_size).and_return(5.megabytes + 1)

    expect(leave_import).not_to be_valid
    expect(leave_import.errors[:file]).to include("must be 5 MB or smaller")
  end

  it "rejects an unknown status" do
    expect(build(:leave_import, status: "paused")).not_to be_valid
  end
end
