class CreateUserSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :user_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :refresh_token_digest, null: false
      t.datetime :last_used_at, null: false
      t.datetime :revoked_at
      t.timestamps
    end
    add_index :user_sessions, :refresh_token_digest, unique: true
    add_index :user_sessions, [ :user_id, :revoked_at ]
  end
end
