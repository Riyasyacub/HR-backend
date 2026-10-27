class AddCalculationStatusToPayrollRuns < ActiveRecord::Migration[8.1]
  def change
    add_column :payroll_runs, :calculation_status, :string, null: false, default: "queued"
    add_column :payroll_runs, :calculation_error, :string
    add_check_constraint :payroll_runs, "calculation_status IN ('queued', 'processing', 'completed', 'failed')",
      name: "payroll_runs_calculation_status_known"
  end
end
