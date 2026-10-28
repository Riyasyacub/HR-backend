# Stands in for an LLM provider in specs: returns queued replies (or raises queued errors) and records requests.
class FakeLlmProvider
  attr_reader :requests

  def self.sql(statement, explanation: nil) = { status: "success", sql: statement, failure_reason: nil, explanation: }.to_json
  def self.cannot_answer(reason) = { status: "cannot_answer", sql: nil, failure_reason: reason }.to_json
  def self.needs_clarification(reason) = { status: "needs_clarification", sql: nil, failure_reason: reason }.to_json

  def initialize(*replies)
    @replies = replies
    @requests = []
  end

  def complete(system:, message:)
    @requests << { system:, message: }
    reply = @replies.shift
    raise reply if reply.is_a?(Exception)

    Assistant::LlmProvider::Completion.new(text: reply, prompt_tokens: 100, completion_tokens: 10)
  end
end
