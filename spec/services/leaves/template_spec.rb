require "rails_helper"

RSpec.describe Leaves::Template do
  before do
    create(:leave_type, name: "Earned")
    create(:leave_type, :unpaid)
  end

  def sheet
    file = Tempfile.new([ "template", ".xlsx" ]).tap { |f| f.binmode && f.write(described_class.to_xlsx) && f.flush }
    Roo::Excelx.new(file.path).sheet(0)
  end

  it "has the header row and an example row" do
    expect(sheet.row(1)).to eq(%w[employee_id leave_date leave_type reason])
    expect(sheet.row(2)).to eq([ "EMP101", Date.new(2026, 10, 28), "earned", "Family function" ])
  end

  it "offers a dropdown of the leave types in the leave_type column" do
    xml = Zip::File.open_buffer(StringIO.new(described_class.to_xlsx)).read("xl/worksheets/sheet1.xml")

    expect(xml).to include('sqref="C2:C1000"', "<formula1>\"earned,unpaid\"</formula1>")
  end
end
