require "rails_helper"

RSpec.describe Leaves::ImportSheet do
  let!(:priya) { create(:employee, employee_id: "EMP902", start_date: Date.new(2026, 1, 1)) }
  let!(:earned) { create(:leave_type, name: "Earned", default_entitlement: 2) }
  let!(:sick) { create(:leave_type, name: "Sick", default_entitlement: 2) }
  let!(:unpaid) { create(:leave_type, :unpaid) }
  let(:header) { %w[employee_id leave_date leave_type reason] }
  let(:wednesday) { Date.new(2026, 10, 28) }

  before { Leaves::GrantEntitlements.call(employee: priya, year: 2026) }

  def import(rows)
    sheet = build_xlsx(rows)
    file = Rack::Test::UploadedFile.new(sheet.path, LeaveImport::XLSX_CONTENT_TYPE, original_filename: "leave.xlsx")
    create(:leave_import, file:).tap { |leave_import| described_class.call(leave_import) }.reload
  end

  def balance(leave_type) = LeaveLedgerEntry.balance(employee: priya, leave_type:, year: 2026)

  it "imports valid rows and records the counts (AC-01)" do
    leave_import = import([ header, [ "EMP902", wednesday, "earned", "Family" ], [ "EMP902", wednesday + 1, "sick" ] ])

    expect(leave_import).to have_attributes(status: "completed", total_rows: 2, imported_rows: 2, row_errors: [])
    expect(LeaveRecord.where(employee: priya).pluck(:leave_date)).to contain_exactly(wednesday, wednesday + 1)
  end

  it "reduces the balance by one day per balanced row (AC-04)" do
    import([ header, [ "EMP902", wednesday, "earned" ] ])

    expect(balance(earned)).to eq(1)
  end

  it "imports unpaid leave without a ledger entry (AC-05, TC-S06-06)" do
    import([ header, [ "EMP902", wednesday, "unpaid" ] ])

    expect(LeaveRecord.find_by!(employee: priya)).to be_payroll_deduction
    expect(LeaveLedgerEntry.where(employee: priya, leave_type: unpaid)).to be_empty
  end

  it "reports row errors and still imports valid rows (AC-03, TC-S06-03)" do
    leave_import = import([ header, [ "EMP999", wednesday, "earned" ], [ "EMP902", wednesday, "earned" ] ])

    expect(leave_import).to have_attributes(total_rows: 2, imported_rows: 1,
      row_errors: [ { "line" => 2, "errors" => [ "unknown employee EMP999" ] } ])
  end

  it "rejects a weekend date (TC-S06-04)" do
    leave_import = import([ header, [ "EMP902", Date.new(2026, 10, 31), "earned" ] ])

    expect(leave_import.row_errors).to eq([ { "line" => 2, "errors" => [ "Leave date must be a working day" ] } ])
  end

  it "rejects a row when the balance is used up (TC-S06-05)" do
    leave_import = import([ header, [ "EMP902", wednesday, "earned" ], [ "EMP902", wednesday + 1, "earned" ],
      [ "EMP902", wednesday + 2, "earned" ] ])

    expect(leave_import.row_errors).to eq([ { "line" => 4, "errors" => [ "insufficient Earned balance" ] } ])
    expect(balance(earned)).to eq(0)
  end

  it "updates instead of duplicating on re-upload (AC-06, TC-S06-07)" do
    rows = [ header, [ "EMP902", wednesday, "earned", "Family" ] ]
    import(rows)
    import(rows)

    expect(LeaveRecord.where(employee: priya).count).to eq(1)
    expect(balance(earned)).to eq(1)
  end

  it "moves the day to the new leave type when re-uploaded with a different type" do
    import([ header, [ "EMP902", wednesday, "earned" ] ])
    import([ header, [ "EMP902", wednesday, "sick" ] ])

    expect([ balance(earned), balance(sick) ]).to eq([ 2, 1 ])
    expect(LeaveRecord.find_by!(employee: priya).leave_type).to eq(sick)
  end

  it "fails the import with the header error and imports nothing (TC-S06-02)" do
    leave_import = import([ %w[employee_id leave_date], [ "EMP902", wednesday ] ])

    expect(leave_import).to have_attributes(status: "failed", error_message: "Missing columns: leave_type")
    expect(LeaveRecord.count).to eq(0)
  end
end
