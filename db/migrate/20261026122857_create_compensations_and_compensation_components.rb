class CreateCompensationsAndCompensationComponents < ActiveRecord::Migration[8.1]
  def change
    create_table :compensations do |t|
      t.references :employee, null: false, foreign_key: true
      t.date :effective_date, null: false
      t.decimal :annual_ctc, precision: 12, scale: 2, null: false
      t.string :currency, null: false
      t.timestamps
    end
    add_index :compensations, %i[employee_id effective_date], unique: true
    add_check_constraint :compensations, "annual_ctc > 0",
      name: "compensations_annual_ctc_positive"

    create_table :compensation_components do |t|
      t.references :compensation, null: false, foreign_key: true
      t.string :name, null: false
      t.decimal :annual_amount, precision: 12, scale: 2, null: false
      t.timestamps
    end
    add_index :compensation_components, "compensation_id, lower(name)", unique: true,
      name: "index_compensation_components_on_compensation_and_name"
    add_check_constraint :compensation_components, "annual_amount > 0",
      name: "compensation_components_annual_amount_positive"
  end
end
