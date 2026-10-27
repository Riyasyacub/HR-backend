require "rails_helper"

RSpec.describe ImportLeaveSheetJob, type: :job do
  it "runs the import for a queued import" do
    leave_import = create(:leave_import)

    described_class.perform_now(leave_import.id)

    expect(leave_import.reload.status).to eq("completed")
  end

  it "skips an import that is no longer queued" do
    leave_import = create(:leave_import, status: "completed", imported_rows: 3)
    allow(Leaves::ImportSheet).to receive(:call)

    described_class.perform_now(leave_import.id)

    expect(Leaves::ImportSheet).not_to have_received(:call)
  end
end
