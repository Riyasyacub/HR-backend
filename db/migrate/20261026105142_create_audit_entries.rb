class CreateAuditEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_entries do |t|
      t.references :actor, null: false, foreign_key: { to_table: :users }
      t.references :auditable, polymorphic: true, null: false
      t.string :action, null: false
      t.jsonb :change_set, null: false, default: {}

      t.timestamps
    end
  end
end
