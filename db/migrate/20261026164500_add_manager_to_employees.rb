class AddManagerToEmployees < ActiveRecord::Migration[8.1]
  def change
    add_reference :employees, :manager, foreign_key: { to_table: :employees }, index: true
    add_check_constraint :employees, "manager_id IS NULL OR manager_id != id",
      name: "check_employees_manager_not_self"
  end
end
