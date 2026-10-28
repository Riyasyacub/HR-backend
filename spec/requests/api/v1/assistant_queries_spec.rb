require "rails_helper"

RSpec.describe "Assistant queries", type: :request do
  let!(:arjun) { create(:employee, user: create(:user), first_name: "Arjun") }
  let!(:priya) { create(:employee, user: create(:user), manager: arjun, first_name: "Priya") }
  let(:hr_headers) { authentication_headers(create(:user, :hr)) }

  def ask(question, headers: hr_headers, replies: [ FakeLlmProvider.sql("SELECT first_name FROM employees ORDER BY first_name", explanation: "Listed employee first names") ])
    provider = FakeLlmProvider.new(*replies)
    allow(Assistant::LlmProvider).to receive(:build).and_return(provider)
    post("/api/v1/assistant/queries", params: { question: }, as: :json, headers:)
    provider
  end

  it "answers HR with columns and rows and never returns the SQL (TC-S11c-01)" do
    ask("list employee names")

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["data"]).to eq("columns" => [ "first_name" ], "rows" => [ [ "Arjun" ], [ "Priya" ] ],
      "row_count" => 2, "truncated" => false, "cached" => false, "explanation" => "Listed employee first names")
    expect(response.body).not_to include("SELECT")
  end

  it "answers an employee only from their own records (TC-S11c-03)" do
    ask("show all employees", headers: authentication_headers(priya.user))

    expect(response.parsed_body["data"]["rows"]).to eq([ [ "Priya" ] ])
  end

  it "rejects a blank or too long question without calling the model" do
    [ " ", "a" * 501 ].each do |question|
      provider = ask(question)
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]["code"]).to eq("validation_failed")
      expect(provider.requests).to be_empty
    end
  end

  it "reports unsafe SQL with a generic message (TC-S11c-04)" do
    ask("drop everything", replies: [ FakeLlmProvider.sql("DELETE FROM employees"), FakeLlmProvider.sql("SELECT * FROM pg_user") ])

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body["error"]).to include("code" => "unsafe_query", "message" => "The generated query was not allowed")
  end

  it "reports a question the model cannot answer" do
    ask("what is the weather", replies: [ FakeLlmProvider.cannot_answer("No weather data in the relations") ])

    expect(response.parsed_body["error"]).to include("code" => "cannot_answer", "message" => "No weather data in the relations")
  end

  it "asks for clarification with the model's question" do
    ask("payroll totals", replies: [ FakeLlmProvider.needs_clarification("Which year do you mean?") ])

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body["error"]).to include("code" => "needs_clarification", "message" => "Which year do you mean?")
  end

  it "returns 429 when the user is rate limited (TC-S11c-07)" do
    user = create(:user, :hr)
    10.times { create(:assistant_query, user:) }

    ask("list employee names", headers: authentication_headers(user))

    expect(response).to have_http_status(:too_many_requests)
    expect(response.parsed_body["error"]["code"]).to eq("rate_limited")
  end

  it "returns 503 when the provider fails (TC-S11c-08)" do
    ask("list employee names", replies: [ Assistant::LlmProvider::Error.new("Provider responded with 503") ])

    expect(response).to have_http_status(:service_unavailable)
    expect(response.parsed_body["error"]["code"]).to eq("assistant_unavailable")
  end

  it "denies a user without an employee record and requires sign-in" do
    ask("list employee names", headers: authentication_headers(create(:user)))
    expect(response).to have_http_status(:forbidden)

    post("/api/v1/assistant/queries", params: { question: "x" }, as: :json)
    expect(response).to have_http_status(:unauthorized)
  end

  describe "GET /api/v1/assistant/queries" do
    let(:user) { arjun.user }

    def history(params = {}, headers = authentication_headers(user))
      get("/api/v1/assistant/queries", params:, headers:)
      response.parsed_body
    end

    def record(question, at:, **attributes)
      create(:assistant_query, user:, question:, created_at: at, generated_sql: "SELECT 1", **attributes)
    end

    it "lists only the caller's questions, newest first, without SQL" do
      record("older", at: 2.hours.ago)
      record("newer", at: 1.hour.ago)
      create(:assistant_query, question: "someone else", generated_sql: "SELECT 2")

      body = history

      expect(body["data"].pluck("question", "status", "message")).to eq([ [ "newer", "answered", nil ], [ "older", "answered", nil ] ])
      expect(body["data"].first.keys).to contain_exactly("id", "question", "status", "message", "created_at")
      expect(response.body).not_to include("SELECT")
    end

    it "paginates with the total in meta" do
      3.times { |index| record("q#{index}", at: index.minutes.ago) }

      body = history(page: 2, per_page: 2)

      expect(body["data"].pluck("question")).to eq(%w[q2])
      expect(body["meta"]).to eq("page" => 2, "per_page" => 2, "total" => 3)
    end

    it "explains failures safely" do
      record("ambiguous", at: 4.minutes.ago, status: "rejected", error_code: "needs_clarification", failure_reason: "Which year?")
      record("weather", at: 3.minutes.ago, status: "rejected", error_code: "cannot_answer", failure_reason: "No weather data")
      record("drop", at: 2.minutes.ago, status: "rejected", error_code: "unsafe_query", failure_reason: "Relation not allowed: pg_user")
      record("down", at: 1.minute.ago, status: "failed", error_code: "assistant_unavailable")

      expect(history["data"].to_h { [ _1["question"], _1["message"] ] }).to eq(
        "down" => "The assistant was unavailable", "drop" => "The generated query was not allowed",
        "weather" => "No weather data", "ambiguous" => "Which year?"
      )
    end

    it "denies a user without an employee record and requires sign-in" do
      history({}, authentication_headers(create(:user)))
      expect(response).to have_http_status(:forbidden)

      get("/api/v1/assistant/queries")
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
