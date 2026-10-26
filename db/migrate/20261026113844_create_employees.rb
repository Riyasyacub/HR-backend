class CreateEmployees < ActiveRecord::Migration[8.1]
  def change
    create_table :employees do |t|
      t.references :user, foreign_key: true, index: { unique: true }
      t.references :department, null: false, foreign_key: true
      t.string :employee_id, null: false
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :work_email, null: false
      t.string :country, null: false
      t.string :currency, null: false
      t.string :job_title, null: false
      t.date :start_date, null: false
      t.string :bank_name, null: false
      t.string :ifsc
      t.string :account_number, null: false
      t.string :status, null: false, default: "onboarding"
      t.timestamps
    end
    add_index :employees, "lower(employee_id)", unique: true,
      name: "index_employees_on_lower_employee_id"
    add_index :employees, "lower(work_email)", unique: true,
      name: "index_employees_on_lower_work_email"
  end
end
