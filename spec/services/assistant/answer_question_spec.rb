require "rails_helper"

RSpec.describe Assistant::AnswerQuestion do
  let!(:arjun) { create(:employee, user: create(:user), first_name: "Arjun", country: "India") }
  let!(:priya) { create(:employee, manager: arjun, first_name: "Priya", country: "India") }
  let!(:robert) { create(:employee, first_name: "Robert", country: "USA") }
  let(:hr) { create(:user, :hr) }

  def ask(provider, user: hr, question: "headcount by country")
    described_class.call(user:, question:, provider:)
  end

  it "answers within the asker's scope and audits the query (AC-01, AC-07)" do
    provider = FakeLlmProvider.new(FakeLlmProvider.sql("SELECT country, count(*) AS headcount FROM employees GROUP BY country ORDER BY country"))

    answer = ask(provider, user: arjun.user)

    expect(answer).to have_attributes(columns: %w[country headcount], rows: [ [ "India", 2 ] ], row_count: 1, truncated: false, cached: false)
    expect(provider.requests.first[:system]).to include("employees(id, employee_id").and include("cannot_answer")
    expect(AssistantQuery.last).to have_attributes(user: arjun.user, status: "answered", row_count: 1, prompt_tokens: 100,
      completion_tokens: 10, generated_sql: start_with("SELECT country"))
  end

  it "accepts a JSON reply wrapped in a code fence and strips a trailing semicolon" do
    answer = ask(FakeLlmProvider.new("```json\n#{FakeLlmProvider.sql('SELECT count(*) AS total FROM employees;')}\n```"))

    expect(answer.rows).to eq([ [ 3 ] ])
  end

  it "repairs once after a database error and sums tokens" do
    provider = FakeLlmProvider.new(FakeLlmProvider.sql("SELECT salary FROM employees"), FakeLlmProvider.sql("SELECT count(*) AS total FROM employees"))

    expect(ask(provider).rows).to eq([ [ 3 ] ])
    expect(provider.requests.last[:message]).to include("SELECT salary FROM employees").and include('column "salary" does not exist')
    expect(AssistantQuery.last).to have_attributes(status: "answered", prompt_tokens: 200, completion_tokens: 20)
  end

  it "rejects unsafe SQL on both attempts without running it (TC-S11c-04)" do
    allow(Assistant::Executor).to receive(:call)

    expect { ask(FakeLlmProvider.new(FakeLlmProvider.sql("DELETE FROM employees"), FakeLlmProvider.sql("DELETE FROM employees"))) }.to raise_error(Assistant::SqlValidator::Unsafe)
    expect(Assistant::Executor).not_to have_received(:call)
    expect(AssistantQuery.last).to have_attributes(status: "rejected", error_code: "unsafe_query", generated_sql: "DELETE FROM employees")
    expect(Employee.count).to eq(3)
  end

  it "rejects a manager's question about compensation (TC-S11c-02)" do
    provider = FakeLlmProvider.new(FakeLlmProvider.sql("SELECT annual_ctc FROM compensations"), FakeLlmProvider.sql("SELECT annual_ctc FROM compensations"))

    expect { ask(provider, user: arjun.user, question: "salaries") }.to raise_error(Assistant::SqlValidator::Unsafe, /compensations/)
  end

  it "stops without a repair when the model cannot answer, keeping its reason" do
    provider = FakeLlmProvider.new(FakeLlmProvider.cannot_answer("No weather data in the relations"))

    expect { ask(provider, question: "what is the weather") }.to raise_error(described_class::CannotAnswer, "No weather data in the relations")
    expect(provider.requests.size).to eq(1)
    expect(AssistantQuery.last).to have_attributes(status: "rejected", error_code: "cannot_answer", failure_reason: "No weather data in the relations")
  end

  it "asks for clarification when the model finds the question ambiguous" do
    provider = FakeLlmProvider.new(FakeLlmProvider.needs_clarification("Which year do you mean?"))

    expect { ask(provider, question: "payroll totals") }.to raise_error(described_class::NeedsClarification, "Which year do you mean?")
    expect(AssistantQuery.last).to have_attributes(status: "rejected", error_code: "needs_clarification", failure_reason: "Which year do you mean?")
  end

  it "treats a reply that is not JSON as cannot answer" do
    expect { ask(FakeLlmProvider.new("SELECT 1")) }.to raise_error(described_class::CannotAnswer, "Model reply was not valid JSON")
    expect(AssistantQuery.last.failure_reason).to eq("Model reply was not valid JSON")
  end

  it "records the validator message when SQL is rejected" do
    ask(FakeLlmProvider.new(FakeLlmProvider.sql("DELETE FROM employees"), FakeLlmProvider.sql("SELECT * FROM pg_user"))) rescue nil

    expect(AssistantQuery.last.failure_reason).to eq("Relation not allowed: pg_user")
  end

  it "frames the system prompt as role, task, context, format and constraints" do
    provider = FakeLlmProvider.new(FakeLlmProvider.sql("SELECT count(*) AS total FROM employees"))

    ask(provider)

    system = provider.requests.first[:system]
    expect(system.scan(/^(ROLE|TASK|CONTEXT|FORMAT|CONSTRAINTS|RELATIONS)\b/).flatten).to eq(%w[ROLE TASK CONTEXT FORMAT CONSTRAINTS RELATIONS])
    expect(system).to include("live company database, which always holds current data")
    expect(system).to include("use it only to work out date ranges")
  end

  it "asks for an explanation and readable, currency-aware results" do
    provider = FakeLlmProvider.new(FakeLlmProvider.sql("SELECT count(*) AS total FROM employees", explanation: "Counted all employees"))

    answer = ask(provider)

    expect(answer.explanation).to eq("Counted all employees")
    expect(provider.requests.first[:system]).to include('"explanation"')
      .and include("readable labels such as names next to any id").and include("also select and group by currency")
  end

  it "sends today's date, the relation notes and the recursive CTE rule to the model" do
    provider = FakeLlmProvider.new(FakeLlmProvider.sql("SELECT count(*) AS total FROM employees"))

    travel_to(Date.new(2026, 10, 28)) { ask(provider) }

    expect(provider.requests.first[:message]).to eq("Today's date: 2026-10-28\nQuestion: headcount by country")
    expect(provider.requests.first[:system]).to include("WITH RECURSIVE").and include("manager_id IS NULL").and include('"failure_reason"')
  end

  it "audits and re-raises a provider failure (TC-S11c-08)" do
    provider = FakeLlmProvider.new(Assistant::LlmProvider::Error.new("Provider responded with 503"))

    expect { ask(provider) }.to raise_error(Assistant::LlmProvider::Error)
    expect(AssistantQuery.last).to have_attributes(status: "failed", error_code: "assistant_unavailable", generated_sql: nil)
  end

  describe "caching and limits" do
    let(:cache) { ActiveSupport::Cache::MemoryStore.new }

    before { allow(Rails).to receive(:cache).and_return(cache) }

    it "serves a repeated question from the result cache without calling the model (TC-S11c-06)" do
      ask(FakeLlmProvider.new(FakeLlmProvider.sql("SELECT count(*) AS total FROM employees", explanation: "Counted all employees")))
      provider = FakeLlmProvider.new

      answer = ask(provider, question: "  HEADCOUNT   by country ")

      expect(answer).to have_attributes(rows: [ [ 3 ] ], cached: true, explanation: "Counted all employees")
      expect(provider.requests).to be_empty
      expect(AssistantQuery.last).to have_attributes(status: "cached", prompt_tokens: 0, completion_tokens: 0)
    end

    it "reuses cached SQL within an access tier but runs it in the asker's own scope" do
      ask(FakeLlmProvider.new(FakeLlmProvider.sql("SELECT count(*) AS total FROM employees", explanation: "Counted all employees")), user: hr)
      provider = FakeLlmProvider.new

      expect(ask(provider, user: create(:user, :hr))).to have_attributes(rows: [ [ 3 ] ], explanation: "Counted all employees")
      expect(provider.requests).to be_empty
    end

    it "calls the model again for a different access tier" do
      ask(FakeLlmProvider.new(FakeLlmProvider.sql("SELECT count(*) AS total FROM employees")), user: hr)
      provider = FakeLlmProvider.new(FakeLlmProvider.sql("SELECT count(*) AS total FROM employees"))

      expect(ask(provider, user: arjun.user).rows).to eq([ [ 2 ] ])
      expect(provider.requests.size).to eq(1)
    end

    it "refuses a rate-limited request before calling the model (TC-S11c-07)" do
      10.times { create(:assistant_query, user: hr) }
      provider = FakeLlmProvider.new

      expect { ask(provider) }.to raise_error(Assistant::UsageLimits::RateLimited)
      expect(provider.requests).to be_empty
      expect(AssistantQuery.last).to have_attributes(status: "rejected", error_code: "rate_limited")
    end
  end
end
