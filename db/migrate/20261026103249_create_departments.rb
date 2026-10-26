class CreateDepartments < ActiveRecord::Migration[8.1]
  def change
    create_table :departments do |t|
      t.string :name, null: false
      t.string :code, null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :departments, "lower((name)::text)", unique: true,
      name: "index_departments_on_lower_name"
    add_index :departments, "lower((code)::text)", unique: true,
      name: "index_departments_on_lower_code"
  end
end
