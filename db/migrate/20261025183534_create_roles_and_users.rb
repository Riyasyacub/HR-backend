class CreateRolesAndUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :roles do |t|
      t.string :name, null: false
      t.timestamps
    end
    add_index :roles, :name, unique: true

    create_table :users do |t|
      t.references :role, null: false, foreign_key: true
      t.string :name, null: false
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :country, null: false
      t.string :status, null: false, default: "active"
      t.boolean :active, null: false, default: true
      t.integer :token_version, null: false, default: 0
      t.timestamps
    end
    add_index :users, "lower(email)", unique: true, name: "index_users_on_lower_email"
  end
end
