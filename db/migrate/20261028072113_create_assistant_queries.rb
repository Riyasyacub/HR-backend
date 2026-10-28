class CreateAssistantQueries < ActiveRecord::Migration[8.1]
  def change
    create_table :assistant_queries do |t|
      t.references :user, null: false, foreign_key: true
      t.string :question, null: false, limit: 500
      t.text :generated_sql
      t.string :status, null: false
      t.string :error_code
      t.integer :row_count
      t.integer :duration_ms
      t.integer :prompt_tokens, null: false, default: 0
      t.integer :completion_tokens, null: false, default: 0
      t.datetime :created_at, null: false
    end
    add_index :assistant_queries, %i[user_id created_at]
    add_check_constraint :assistant_queries, "status IN ('answered', 'cached', 'rejected', 'failed')",
      name: "assistant_queries_status_known"
  end
end
