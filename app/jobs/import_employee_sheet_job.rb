class ImportEmployeeSheetJob < ApplicationJob
  class ImportInProgress < StandardError; end

  LOCK_KEY = 11_001

  queue_as :default
  retry_on ImportInProgress, wait: 30.seconds, attempts: 20

  def self.acquire_lock = ActiveRecord::Base.connection.select_value("SELECT pg_try_advisory_lock(#{LOCK_KEY})")
  def self.release_lock = ActiveRecord::Base.connection.select_value("SELECT pg_advisory_unlock(#{LOCK_KEY})")

  def perform(employee_import_id)
    raise ImportInProgress unless (locked = self.class.acquire_lock)

    claimed = EmployeeImport.where(id: employee_import_id, status: "queued").update_all(status: "processing", updated_at: Time.current)
    Employees::ImportSheet.call(EmployeeImport.find(employee_import_id)) if claimed == 1
  rescue ActiveRecord::ActiveRecordError => e
    EmployeeImport.where(id: employee_import_id).update_all(status: "failed", error_message: e.message, updated_at: Time.current)
    raise
  ensure
    self.class.release_lock if locked
  end
end
