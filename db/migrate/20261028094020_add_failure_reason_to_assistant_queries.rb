class AddFailureReasonToAssistantQueries < ActiveRecord::Migration[8.1]
  def change
    add_column :assistant_queries, :failure_reason, :string, limit: 500
  end
end
