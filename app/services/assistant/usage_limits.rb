module Assistant
  # Counts from the audit table, so limits hold across processes and do not depend on the cache store.
  class UsageLimits
    class RateLimited < StandardError; end
    class BudgetExceeded < RateLimited; end

    def self.check_rate!(user, config = Rails.configuration.x.assistant)
      return if AssistantQuery.where(user:, created_at: 1.minute.ago..).count < config[:requests_per_minute]

      raise RateLimited, "Too many questions; try again in a minute"
    end

    def self.check_budget!(user, config = Rails.configuration.x.assistant)
      used = AssistantQuery.where(user:, created_at: Time.current.all_day).sum("prompt_tokens + completion_tokens")
      raise BudgetExceeded, "Today's assistant budget is used up" if used >= config[:daily_token_budget]
    end
  end
end
