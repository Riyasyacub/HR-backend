require "rails_helper"

RSpec.describe Reports::Leave do
  it "builds export rows in batches, in employee ID order, covering every employee" do
    earned = create(:leave_type, name: "Earned", default_entitlement: 6)
    %w[EMP203 EMP201 EMP202].each do |code|
      create(:leave_ledger_entry, employee: create(:employee, employee_id: code, start_date: Date.new(2026, 1, 1)), leave_type: earned)
    end
    report = described_class.new(Employee.order(:employee_id), year: 2026)

    expect(report.export_headers).to eq([ "Employee ID", "Name", "Earned entitled", "Earned used", "Earned remaining", "Unpaid days" ])
    expect(report.export_rows(batch_size: 2).map(&:first)).to eq(%w[EMP201 EMP202 EMP203 Total])
    expect(report.export_rows(batch_size: 2).last).to eq([ "Total", nil, 18, 0, 18, 0 ])
  end
end
