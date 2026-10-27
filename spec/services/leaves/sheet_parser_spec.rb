require "rails_helper"

RSpec.describe Leaves::SheetParser do
  let!(:priya) { create(:employee, employee_id: "EMP902") }
  let!(:earned) { create(:leave_type, name: "Earned") }
  let(:header) { %w[employee_id leave_date leave_type reason] }

  def parse(rows) = described_class.call(build_xlsx(rows).path)

  it "parses valid rows into employee, leave type, date and reason" do
    rows = parse([ header, [ "EMP902", Date.new(2026, 10, 28), "earned", "Family function" ] ])

    expect(rows.first).to have_attributes(line: 2, employee: priya, leave_type: earned,
      leave_date: Date.new(2026, 10, 28), reason: "Family function", errors: [])
  end

  it "accepts a date typed as YYYY-MM-DD text" do
    rows = parse([ header, [ "EMP902", "2026-10-28", "earned" ] ])

    expect(rows.first).to have_attributes(leave_date: Date.new(2026, 10, 28), errors: [])
  end

  it "rejects a sheet missing a required header (TC-S06-02)" do
    expect { parse([ %w[employee_id leave_date reason], [ "EMP902", "2026-10-28", "x" ] ]) }
      .to raise_error(described_class::HeaderError, "Missing columns: leave_type")
  end

  it "rejects a file that is not a valid Excel workbook" do
    file = Tempfile.new([ "leave", ".xlsx" ]).tap { |f| f.write("not a workbook") && f.flush }

    expect { described_class.call(file.path) }
      .to raise_error(described_class::HeaderError, "File is not a valid Excel (.xlsx) workbook")
  end

  it "accepts headers in any order and case and ignores extra columns" do
    rows = parse([ %w[Leave_Type EXTRA Employee_ID leave_date], [ "Earned", "x", "emp902", "2026-10-28" ] ])

    expect(rows.first).to have_attributes(employee: priya, leave_type: earned, errors: [])
  end

  it "skips blank rows" do
    rows = parse([ header, [ "EMP902", "2026-10-28", "earned" ], [ nil, nil, nil ] ])

    expect(rows.size).to eq(1)
  end

  it "reports an unknown employee ID against its line (TC-S06-03)" do
    rows = parse([ header, [ "EMP902", "2026-10-28", "earned" ], [ "EMP999", "2026-10-28", "earned" ] ])

    expect(rows.map(&:errors)).to eq([ [], [ "unknown employee EMP999" ] ])
    expect(rows.last.line).to eq(3)
  end

  it "reports an invalid date and an unknown leave type" do
    rows = parse([ header, [ "EMP902", "28/10/2026", "vacation" ] ])

    expect(rows.first.errors).to eq([ "leave_date must be a date or YYYY-MM-DD", "unknown leave type vacation" ])
  end

  it "looks up employees in one query" do
    create_list(:employee, 3)
    rows = [ header ] + Employee.pluck(:employee_id).map { [ _1, "2026-10-28", "earned" ] }
    queries = []
    callback = ->(*, payload) { queries << payload[:sql] if payload[:sql].include?("FROM \"employees\"") }

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { parse(rows) }

    expect(queries.size).to eq(1)
  end
end
