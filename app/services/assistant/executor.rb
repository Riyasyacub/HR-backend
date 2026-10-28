module Assistant
  class Executor
    class Timeout < StandardError; end
    class QueryFailed < StandardError; end

    ROW_LIMIT = 200
    Result = Data.define(:columns, :rows, :truncated)

    # Runs inside a savepoint so read-only mode and the timeout apply even when a caller already holds a transaction.
    def self.call(sql, schema:, relations:, limit: ROW_LIMIT, timeout: "3s")
      connection = ActiveRecord::Base.connection
      statement = "#{schema.cte_sql(only: relations)} SELECT * FROM (#{sql}) assistant_result LIMIT #{Integer(limit) + 1}"
      result = nil
      connection.transaction(requires_new: true) do
        connection.execute("SET LOCAL transaction_read_only = on")
        connection.execute("SET LOCAL statement_timeout = #{connection.quote(timeout)}")
        result = connection.select_all(statement)
        raise ActiveRecord::Rollback
      end
      Result.new(columns: result.columns, rows: result.rows.first(limit), truncated: result.rows.size > limit)
    rescue ActiveRecord::QueryCanceled
      raise Timeout, "Query took too long"
    rescue ActiveRecord::StatementInvalid => e
      raise QueryFailed, (e.cause&.message || e.message).lines.first.to_s.strip
    end
  end
end
