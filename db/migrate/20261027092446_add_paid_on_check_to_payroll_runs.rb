class AddPaidOnCheckToPayrollRuns < ActiveRecord::Migration[8.1]
  def change
    add_check_constraint :payroll_runs, "status <> 'paid' OR paid_on IS NOT NULL", name: "payroll_runs_paid_on_when_paid"
  end
end
