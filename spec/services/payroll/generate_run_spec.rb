require "rails_helper"

RSpec.describe Payroll::GenerateRun do
  let(:run) { create(:payroll_run, calculation_status: "completed") }
  let(:priya) { create(:employee, employee_id: "EMP102", first_name: "Priya", last_name: "Sharma") }

  it "generates a completed draft without blocking issues and freezes employee and bank details" do
    line = create(:payroll_line, payroll_run: run, employee: priya)

    described_class.call(run)
    priya.update!(bank_name: "ICICI Bank", account_number: "999")

    expect(run.reload.status).to eq("generated")
    expect(line.reload).to have_attributes(employee_code: "EMP102", employee_name: "Priya Sharma",
      bank_name: "HDFC Bank", ifsc: "HDFC0001234", account_number: "123456789012")
  end

  it "refuses a run with blocking issues" do
    create(:payroll_line, payroll_run: run, blocking_issues: [ "missing account number" ])

    expect { described_class.call(run) }.to raise_error(described_class::NotGeneratable)
    expect(run.reload.status).to eq("draft")
  end

  it "refuses a run whose calculation is not completed" do
    run.update!(calculation_status: "processing")

    expect { described_class.call(run) }.to raise_error(described_class::NotGeneratable)
  end

  it "refuses a run that is already generated (AC-04)" do
    run.update!(status: "generated")

    expect { described_class.call(run) }.to raise_error(described_class::NotGeneratable)
  end
end
