class CreateLeaveImportsRecordsAndLedger < ActiveRecord::Migration[8.1]
  def change
    create_table :leave_imports do |t|
      t.references :uploaded_by, null: false, foreign_key: { to_table: :users }
      t.string :status, null: false, default: "queued"
      t.integer :total_rows, null: false, default: 0
      t.integer :imported_rows, null: false, default: 0
      t.jsonb :row_errors, null: false, default: []
      t.string :error_message
      t.timestamps
    end
    add_check_constraint :leave_imports, "status IN ('queued', 'processing', 'completed', 'failed')",
      name: "leave_imports_status_known"

    create_table :leave_records do |t|
      t.references :employee, null: false, foreign_key: true
      t.references :leave_type, null: false, foreign_key: true
      t.references :leave_import, foreign_key: true
      t.date :leave_date, null: false
      t.string :reason
      t.timestamps
    end
    add_index :leave_records, %i[employee_id leave_date], unique: true

    create_table :leave_ledger_entries do |t|
      t.references :employee, null: false, foreign_key: true
      t.references :leave_type, null: false, foreign_key: true
      t.references :leave_record, foreign_key: true
      t.integer :year, null: false
      t.string :entry_type, null: false
      t.integer :days, null: false
      t.timestamps
    end
    add_index :leave_ledger_entries, %i[employee_id leave_type_id year]
    add_index :leave_ledger_entries, %i[employee_id leave_type_id year], unique: true,
      where: "entry_type = 'entitlement'", name: "index_leave_ledger_entries_one_entitlement"
    add_check_constraint :leave_ledger_entries, "entry_type IN ('entitlement', 'used', 'reversal')",
      name: "leave_ledger_entries_entry_type_known"
    add_check_constraint :leave_ledger_entries, "days <> 0", name: "leave_ledger_entries_days_nonzero"
  end
end
