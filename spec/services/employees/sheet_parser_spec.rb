require "rails_helper"

RSpec.describe Employees::SheetParser do
  let!(:engineering) { create(:department, name: "Engineering", code: "ENG") }
  let(:header) do
    %w[employee_id first_name last_name work_email country department job_title start_date
      bank_name account_number manager_employee_id ifsc] + [ "Basic", "HRA", "Special Allowance" ]
  end
  let(:priya) do
    [ "emp102", "Priya", "Sharma", "priya@demo.test", "India", "Engineering", "Engineer", Date.new(2026, 1, 5),
      "HDFC Bank", 123_456_789_012, "EMP101", "HDFC0001234", 900_000, 300_000, nil ]
  end

  def parse(rows) = described_class.call(build_xlsx(rows).path)

  it "maps a valid row to employee attributes, components and manager employee ID" do
    row = parse([ header, priya ]).first

    expect(row).to have_attributes(line: 2, manager_employee_id: "EMP101", errors: [])
    expect(row.attributes).to include(employee_id: "emp102", first_name: "Priya", work_email: "priya@demo.test",
      department: engineering, start_date: Date.new(2026, 1, 5), account_number: "123456789012", status: "active")
    expect(row.attributes).not_to have_key(:component)
    expect(row.components).to eq([ { name: "Basic", annual_amount: 900_000 }, { name: "HRA", annual_amount: 300_000 } ])
  end

  it "skips blank component cells and matches the department by code" do
    row = parse([ header, priya[0..4] + [ "eng" ] + priya[6..12] + [ nil, nil ] ]).first

    expect(row.components).to eq([ { name: "Basic", annual_amount: 900_000 } ])
    expect(row.attributes[:department]).to eq(engineering)
  end

  it "rejects missing required or component columns" do
    expect { parse([ header - %w[work_email], priya ]) }.to raise_error(described_class::HeaderError, "Missing columns: work_email")
    expect { parse([ header - [ "HRA" ], priya ]) }.to raise_error(described_class::HeaderError, "Missing columns: hra")
  end

  it "imports every employee as active and ignores a status column" do
    row = parse([ header + %w[status], priya + %w[onboarding] ]).first

    expect(row.attributes[:status]).to eq("active")
  end

  it "reports row errors for department, start date and component amounts" do
    bad = priya.dup.tap { |row| row[5] = "Sales" }
    bad[7] = "05/01/2026"
    bad[12] = -5
    bad[13] = nil

    expect(parse([ header, bad ]).first.errors).to contain_exactly("unknown department Sales",
      "start_date must be a date or YYYY-MM-DD", "Basic must be a positive amount", "at least one component amount is required")
  end

  it "reports a duplicate employee ID or work email within the file" do
    second = priya.dup.tap { |row| row[3] = "other@demo.test" }
    third = priya.dup.tap { |row| row[0] = "EMP103" }

    rows = parse([ header, priya, second, third ])

    expect(rows.map(&:errors)).to eq([ [], [ "duplicate employee_id in file" ], [ "duplicate work_email in file" ] ])
  end

  it "skips blank rows and rejects a file that is not a workbook" do
    expect(parse([ header, Array.new(header.size), priya ]).map(&:line)).to eq([ 3 ])

    file = Tempfile.new([ "employees", ".xlsx" ]).tap { |f| f.write("not a workbook") && f.flush }
    expect { described_class.call(file.path) }.to raise_error(described_class::HeaderError, "File is not a valid Excel (.xlsx) workbook")
  end

  describe "update mode" do
    let(:update_header) { %w[employee_id manager_employee_id effective_date] + [ "Basic", "HRA", "Special Allowance" ] }

    def parse_update(rows) = described_class.call(build_xlsx(rows).path, mode: "update")

    it "needs only the employee ID and reads components, manager and effective date" do
      row = parse_update([ update_header, [ "emp102", "EMP101", Date.new(2026, 11, 1), 1_000_000, nil, nil ] ]).first

      expect(row).to have_attributes(manager_employee_id: "EMP101", effective_date: Date.new(2026, 11, 1), errors: [])
      expect(row.attributes).to eq(employee_id: "emp102")
      expect(row.components).to eq([ { name: "Basic", annual_amount: 1_000_000 } ])
    end

    it "accepts a manager-only row without checking department or start date" do
      manager_only = priya.dup
      manager_only[5] = "Sales"
      manager_only[7] = "soon"
      manager_only[12] = manager_only[13] = nil
      rows = parse_update([ header, manager_only ])

      expect(rows.first).to have_attributes(components: [], effective_date: nil, errors: [])
    end

    it "reports an invalid effective date and a duplicate employee ID" do
      rows = parse_update([ update_header, [ "EMP102", nil, "next month", nil, nil, nil ], [ "EMP102", nil, nil, nil, nil, nil ] ])

      expect(rows.map(&:errors)).to eq([ [ "effective_date must be a date or YYYY-MM-DD" ], [ "duplicate employee_id in file" ] ])
    end
  end
end
