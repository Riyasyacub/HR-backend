class Api::V1::Settings::LeaveTypesController < ApplicationController
  before_action :authenticate_user!
  after_action :verify_authorized

  def index
    authorize LeaveType
    leave_types = LeaveType.ordered
    render json: { data: leave_types.map { |leave_type| leave_type_json(leave_type) },
      meta: { page: 1, per_page: leave_types.size, total: leave_types.size } }
  end

  def update
    authorize leave_type, :update?
    previous = leave_type.default_entitlement
    LeaveType.transaction do
      leave_type.update!(params.expect(leave_type: [ :default_entitlement ]))
      record_entitlement_audit(previous)
    end
    render json: { data: leave_type_json(leave_type) }
  rescue ActiveRecord::RecordInvalid => error
    render_error(status: :unprocessable_content, code: "validation_failed",
      message: error.record.errors.full_messages.to_sentence,
      details: error.record.errors.full_messages)
  end

  private

  def leave_type
    @leave_type ||= LeaveType.find(params[:id])
  end

  def record_entitlement_audit(previous)
    return if previous == leave_type.default_entitlement

    AuditEntry.create!(actor: current_user, auditable: leave_type, action: "update",
      change_set: { "default_entitlement" => { "from" => previous, "to" => leave_type.default_entitlement } })
  end

  def leave_type_json(leave_type)
    leave_type.as_json(only: %i[id name default_entitlement])
      .merge("balance_tracked" => leave_type.balance_tracked?)
  end
end
