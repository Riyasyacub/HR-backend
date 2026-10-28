class Api::V1::AssistantQueriesController < ApplicationController
  MAX_QUESTION_LENGTH = 500
  HISTORY_MESSAGES = { "unsafe_query" => "The generated query was not allowed", "rate_limited" => "Too many questions at that time",
    "assistant_unavailable" => "The assistant was unavailable", "timeout" => "The assistant was unavailable" }.freeze

  before_action :authenticate_user!
  after_action :verify_authorized

  def index
    authorize AssistantQuery
    page = [ params.fetch(:page, 1).to_i, 1 ].max
    per_page = params.fetch(:per_page, 20).to_i.clamp(1, 100)
    queries = policy_scope(AssistantQuery).order(created_at: :desc, id: :desc)
    render json: { data: queries.offset((page - 1) * per_page).limit(per_page).map { history_json(_1) },
      meta: { page:, per_page:, total: queries.count } }
  end

  def create
    authorize :assistant, :create?
    question = params[:question].to_s.strip
    unless question.length.between?(1, MAX_QUESTION_LENGTH)
      return render_error(status: :unprocessable_content, code: "validation_failed",
        message: "Question must be 1 to #{MAX_QUESTION_LENGTH} characters")
    end

    answer = Assistant::AnswerQuestion.call(user: current_user, question:)
    render json: { data: answer.to_h.slice(:columns, :rows, :row_count, :truncated, :cached, :explanation) }
  rescue Assistant::AnswerQuestion::NeedsClarification => e
    render_error(status: :unprocessable_content, code: "needs_clarification", message: e.message)
  rescue Assistant::AnswerQuestion::CannotAnswer => e
    render_error(status: :unprocessable_content, code: "cannot_answer", message: e.message)
  rescue Assistant::SqlValidator::Unsafe
    render_error(status: :unprocessable_content, code: "unsafe_query", message: "The generated query was not allowed")
  rescue Assistant::UsageLimits::RateLimited => e
    render_error(status: :too_many_requests, code: "rate_limited", message: e.message)
  rescue Assistant::LlmProvider::Error, Assistant::Executor::Timeout
    render_error(status: :service_unavailable, code: "assistant_unavailable", message: "The assistant is unavailable; try again shortly")
  end

  private

  def history_json(query)
    { id: query.id, question: query.question, status: query.status, created_at: query.created_at,
      message: query.error_code && (HISTORY_MESSAGES[query.error_code] || query.failure_reason) }
  end
end
