require "rails_helper"

RSpec.describe AssistantQuery, type: :model do
  it "records an answered question with its SQL, rows and tokens" do
    query = create(:assistant_query, generated_sql: "SELECT 1", row_count: 1, prompt_tokens: 120, completion_tokens: 30)

    expect(query.reload).to have_attributes(status: "answered", generated_sql: "SELECT 1", row_count: 1, prompt_tokens: 120)
  end

  it "requires a question of at most 500 characters" do
    expect(build(:assistant_query, question: "")).not_to be_valid
    expect(build(:assistant_query, question: "a" * 501)).not_to be_valid
  end

  it "rejects an unknown status, also in the database" do
    expect(build(:assistant_query, status: "guessed")).not_to be_valid
    expect { described_class.insert({ user_id: create(:user).id, question: "q", status: "guessed", created_at: Time.current }) }
      .to raise_error(ActiveRecord::StatementInvalid, /assistant_queries_status_known/)
  end

  it "cannot be changed once recorded" do
    query = create(:assistant_query)

    expect { query.update!(row_count: 99) }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end

  it "has pg_query available for SQL validation" do
    expect(PgQuery.parse("SELECT 1").tree.stmts.size).to eq(1)
  end
end
