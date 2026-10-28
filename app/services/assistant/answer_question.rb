module Assistant
  class AnswerQuestion
    class CannotAnswer < StandardError; end
    class NeedsClarification < CannotAnswer; end

    Answer = Data.define(:columns, :rows, :row_count, :truncated, :cached, :explanation)
    # Static instructions come first so providers with prompt caching can reuse them across users.
    INSTRUCTIONS = <<~TEXT.freeze
      ROLE
      You are a PostgreSQL expert working behind the built-in assistant of an HR system.

      TASK
      Turn the user's question into one read-only SQL query that answers it, or say why you cannot.

      CONTEXT
      - Your SQL runs against the live company database, which always holds current data. You never see or need the data yourself.
      - Each message starts with today's date; use it only to work out date ranges such as "this month" or "last year".
      - The relations below are already limited to what the asker may see, so never add permission filters.
      - Prefer the summary views below (top-level managers, leave balances, current compensation, payroll summary) when they fit.

      FORMAT
      Reply with one JSON object and nothing else:
      {"status": "success" | "cannot_answer" | "needs_clarification", "sql": string or null, "failure_reason": string or null, "explanation": string or null}
      - success: "sql" holds the query, "failure_reason" is null, and "explanation" is one plain-English sentence saying what the query computes (what it sums or counts, the period, any status filter, and the grouping), without SQL.
      - cannot_answer: the relations below do not hold the data needed; "failure_reason" names what is missing.
      - needs_clarification: the question is ambiguous; "failure_reason" is the question to ask the user.

      CONSTRAINTS
      - Exactly one SELECT statement; WITH and WITH RECURSIVE are allowed. No INSERT, UPDATE, DELETE, DDL, or locking clauses.
      - Use only the relations and columns below, without schema names, and common functions (count, sum, avg, min, max, round, coalesce, date_trunc, extract, to_char, lower, upper).
      - Never add amounts in different currencies together; when you sum or average amounts, also select and group by currency.
      - Include readable labels such as names next to any id you return.
      - Use cannot_answer only when the data is missing from the relations, never because a date is recent.

      RELATIONS (notes after "--")
    TEXT

    def self.call(user:, question:, provider: LlmProvider.build) = new(user:, question:, provider:).call

    def initialize(user:, question:, provider:)
      @user, @question, @provider = user, question, provider
      @schema = ScopedSchema.new(user)
      @tokens = { prompt_tokens: 0, completion_tokens: 0 }
      @started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def call
      UsageLimits.check_rate!(@user)
      if cached_result
        @explanation = cached_result[:explanation]
        return answer(cached_result[:result], status: "cached")
      end

      result = cached_sql_result || generate_and_run
      Rails.cache.write(result_key, { result:, explanation: @explanation }, expires_in: 5.minutes)
      answer(result, status: @tokens.values.sum.zero? ? "cached" : "answered")
    rescue UsageLimits::RateLimited
      audit("rejected", error_code: "rate_limited")
      raise
    rescue SqlValidator::Unsafe => e
      audit("rejected", error_code: "unsafe_query", failure_reason: e.message)
      raise
    rescue NeedsClarification
      audit("rejected", error_code: "needs_clarification")
      raise
    rescue CannotAnswer
      audit("rejected", error_code: "cannot_answer")
      raise
    rescue Executor::QueryFailed => e
      audit("rejected", error_code: "cannot_answer", failure_reason: e.message)
      raise CannotAnswer, "The assistant could not answer that question"
    rescue LlmProvider::Error, Executor::Timeout => e
      audit("failed", error_code: e.is_a?(Executor::Timeout) ? "timeout" : "assistant_unavailable")
      raise
    end

    private

    def generate_and_run
      UsageLimits.check_budget!(@user)
      result = begin
        run(ask(@question))
      rescue SqlValidator::Unsafe, Executor::QueryFailed => e
        run(ask("#{@question}\n\nYour previous SQL:\n#{@sql}\nfailed with: #{e.message}\nReply with a corrected query."))
      end
      Rails.cache.write(sql_key, { sql: @sql, explanation: @explanation }, expires_in: 1.day)
      result
    end

    def cached_result = @cached_result ||= Rails.cache.read(result_key)

    def cached_sql_result
      cached = Rails.cache.read(sql_key) or return
      @sql, @explanation = cached.values_at(:sql, :explanation)
      run(@sql)
    rescue SqlValidator::Unsafe, Executor::QueryFailed
      @sql = nil
    end

    def answer(result, status:)
      audit(status, row_count: result.rows.size)
      Answer.new(columns: result.columns, rows: result.rows, row_count: result.rows.size, truncated: result.truncated,
        cached: status == "cached", explanation: @explanation)
    end

    def normalized_question = Digest::SHA256.hexdigest(@question.downcase.squish)
    def sql_key = [ "assistant:sql:v2", @schema.tier, Digest::SHA256.hexdigest(@schema.prompt_schema), normalized_question ].join(":")
    def result_key = [ "assistant:result:v2", @user.id, normalized_question ].join(":")

    def ask(prompt)
      completion = @provider.complete(system: INSTRUCTIONS + @schema.prompt_schema, message: "Today's date: #{Date.current.iso8601}\nQuestion: #{prompt}")
      @tokens.merge!(prompt_tokens: @tokens[:prompt_tokens] + completion.prompt_tokens, completion_tokens: @tokens[:completion_tokens] + completion.completion_tokens)
      reply = parse_reply(completion.text)
      @failure_reason = reply["failure_reason"].presence
      @explanation = reply["explanation"].presence
      case reply["status"]
      when "success" then @sql = reply["sql"].to_s.strip.delete_suffix(";").strip.presence || raise(CannotAnswer, "Model returned no SQL")
      when "needs_clarification" then raise NeedsClarification, @failure_reason || "Please clarify the question"
      else raise CannotAnswer, @failure_reason || "Model gave no reason"
      end
    end

    def parse_reply(text)
      reply = JSON.parse(text.strip.sub(/\A```(?:json)?\s*/i, "").sub(/\s*```\z/, ""))
      reply.is_a?(Hash) ? reply : raise(JSON::ParserError)
    rescue JSON::ParserError
      @failure_reason = "Model reply was not valid JSON"
      raise CannotAnswer, @failure_reason
    end

    def run(sql) = Executor.call(sql, schema: @schema, relations: SqlValidator.call(sql, allowed_relations: @schema.relations.keys))

    def audit(status, error_code: nil, row_count: nil, failure_reason: @failure_reason)
      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - @started_at) * 1000).round
      AssistantQuery.create!(user: @user, question: @question, generated_sql: @sql, status:, error_code:, row_count:, duration_ms:,
        failure_reason: failure_reason&.truncate(500), **@tokens)
    end
  end
end
