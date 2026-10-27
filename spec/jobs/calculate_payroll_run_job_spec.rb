require "rails_helper"

RSpec.describe CalculatePayrollRunJob, type: :job do
  it "claims a queued run and calculates it" do
    run = create(:payroll_run)

    described_class.perform_now(run.id)

    expect(run.reload.calculation_status).to eq("completed")
  end

  it "does nothing when the run is already being processed" do
    run = create(:payroll_run, calculation_status: "processing")
    allow(Payroll::GenerateLines).to receive(:call)

    described_class.perform_now(run.id)

    expect(Payroll::GenerateLines).not_to have_received(:call)
  end

  it "marks the calculation failed and re-raises on a database error" do
    run = create(:payroll_run)
    allow(Payroll::GenerateLines).to receive(:call).and_raise(ActiveRecord::StatementInvalid, "boom")

    expect { described_class.perform_now(run.id) }.to raise_error(ActiveRecord::StatementInvalid)
    expect(run.reload).to have_attributes(calculation_status: "failed", calculation_error: "boom")
  end
end
