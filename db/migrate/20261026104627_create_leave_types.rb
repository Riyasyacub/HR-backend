class CreateLeaveTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :leave_types do |t|
      t.string :name, null: false
      t.integer :default_entitlement

      t.timestamps
    end

    add_index :leave_types, "lower((name)::text)", unique: true,
      name: "index_leave_types_on_lower_name"
    add_check_constraint :leave_types,
      "default_entitlement IS NULL OR default_entitlement >= 0",
      name: "leave_types_default_entitlement_non_negative"
  end
end
