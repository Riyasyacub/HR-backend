require "rails_helper"

RSpec.describe ImportEmployeeSheetJob, type: :job do
  it "claims a queued import once and skips one that is no longer queued" do
    employee_import = create(:employee_import)
    allow(Employees::ImportSheet).to receive(:call)

    described_class.perform_now(employee_import.id)
    described_class.perform_now(employee_import.id)

    expect(Employees::ImportSheet).to have_received(:call).once
    expect(employee_import.reload.status).to eq("processing")
  end

  it "retries later while another employee import holds the lock" do
    employee_import = create(:employee_import)
    allow(described_class).to receive(:acquire_lock).and_return(false)

    expect { described_class.perform_now(employee_import.id) }.to have_enqueued_job(described_class).with(employee_import.id)
    expect(employee_import.reload.status).to eq("queued")
  end

  it "marks the import failed and re-raises on a database error" do
    employee_import = create(:employee_import)
    allow(Employees::ImportSheet).to receive(:call).and_raise(ActiveRecord::Deadlocked, "deadlock detected")

    expect { described_class.perform_now(employee_import.id) }.to raise_error(ActiveRecord::Deadlocked)
    expect(employee_import.reload).to have_attributes(status: "failed", error_message: "deadlock detected")
  end
end
