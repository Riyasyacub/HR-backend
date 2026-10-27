class CreatePayrollRunsAndLines < ActiveRecord::Migration[8.1]
  def change
    create_table :payroll_runs do |t|
      t.date :month, null: false
      t.string :status, null: false, default: "draft"
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :payroll_runs, :month, unique: true
    add_check_constraint :payroll_runs, "status IN ('draft', 'generated', 'paid')", name: "payroll_runs_status_known"

    create_table :payroll_lines do |t|
      t.references :payroll_run, null: false, foreign_key: true
      t.references :employee, null: false, foreign_key: true
      t.string :country, null: false
      t.string :currency, null: false
      t.decimal :monthly_gross, precision: 12, scale: 2, null: false, default: 0
      t.integer :working_days, null: false
      t.integer :unpaid_days, null: false, default: 0
      t.decimal :unpaid_deduction, precision: 12, scale: 2, null: false, default: 0
      t.decimal :total, precision: 12, scale: 2, null: false, default: 0
      t.jsonb :blocking_issues, null: false, default: []
      t.timestamps
    end
    add_index :payroll_lines, %i[payroll_run_id employee_id], unique: true
  end
end
