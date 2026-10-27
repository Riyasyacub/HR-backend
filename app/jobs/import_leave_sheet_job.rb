class ImportLeaveSheetJob < ApplicationJob
  queue_as :default

  def perform(leave_import_id)
    leave_import = LeaveImport.find(leave_import_id)
    Leaves::ImportSheet.call(leave_import) if leave_import.status == "queued"
  end
end
