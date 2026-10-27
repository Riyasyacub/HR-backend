class CalculatePayrollRunJob < ApplicationJob
  queue_as :default

  def perform(payroll_run_id)
    return unless claim(payroll_run_id)

    Payroll::GenerateLines.call(PayrollRun.find(payroll_run_id))
  rescue ActiveRecord::ActiveRecordError => e
    PayrollRun.where(id: payroll_run_id)
      .update_all(calculation_status: "failed", calculation_error: e.message, updated_at: Time.current)
    raise
  end

  private

  # Atomic claim so a retried or duplicate job never calculates the same run twice at once.
  def claim(payroll_run_id)
    PayrollRun.where(id: payroll_run_id, calculation_status: "queued")
      .update_all(calculation_status: "processing", calculation_error: nil, updated_at: Time.current) == 1
  end
end
