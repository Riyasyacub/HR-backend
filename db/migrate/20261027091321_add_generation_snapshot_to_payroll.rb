class AddGenerationSnapshotToPayroll < ActiveRecord::Migration[8.1]
  def change
    change_table :payroll_lines, bulk: true do |t|
      t.string :employee_code
      t.string :employee_name
      t.string :bank_name
      t.string :ifsc
      t.string :account_number
    end
    add_column :payroll_runs, :paid_on, :date
  end
end
