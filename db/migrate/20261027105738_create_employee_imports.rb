class CreateEmployeeImports < ActiveRecord::Migration[8.1]
  def change
    create_table :employee_imports do |t|
      t.references :uploaded_by, null: false, foreign_key: { to_table: :users }
      t.string :mode, null: false, default: "create"
      t.string :status, null: false, default: "queued"
      t.integer :total_rows, null: false, default: 0
      t.integer :imported_rows, null: false, default: 0
      t.jsonb :row_errors, null: false, default: []
      t.string :error_message
      t.timestamps
    end
    add_check_constraint :employee_imports, "mode IN ('create', 'update')", name: "employee_imports_mode_known"
    add_check_constraint :employee_imports, "status IN ('queued', 'processing', 'completed', 'failed')",
      name: "employee_imports_status_known"
  end
end
