require "rails_helper"

RSpec.describe Assistant::UsageLimits do
  let(:user) { create(:user) }

  around { |example| travel_to(Time.zone.local(2026, 10, 28, 12, 0, 0)) { example.run } }

  def record(at:, tokens: 0)
    create(:assistant_query, user:, created_at: at, prompt_tokens: tokens)
  end

  it "allows the configured requests per minute, then blocks until the minute passes" do
    10.times { record(at: 30.seconds.ago) }
    expect { described_class.check_rate!(user) }.to raise_error(described_class::RateLimited)

    travel 31.seconds
    expect { described_class.check_rate!(user) }.not_to raise_error
    expect { described_class.check_rate!(create(:user)) }.not_to raise_error
  end

  it "blocks model calls once today's tokens reach the daily budget" do
    record(at: 1.day.ago, tokens: 49_000)
    record(at: 2.hours.ago, tokens: 49_999)
    expect { described_class.check_budget!(user) }.not_to raise_error

    record(at: 1.hour.ago, tokens: 1)
    expect { described_class.check_budget!(user) }.to raise_error(described_class::BudgetExceeded)
  end
end
