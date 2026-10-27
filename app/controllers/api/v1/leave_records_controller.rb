class Api::V1::LeaveRecordsController < ApplicationController
  DEFAULT_PER_PAGE = 25

  before_action :authenticate_user!
  after_action :verify_authorized

  def index
    authorize LeaveRecord
    scope = policy_scope(LeaveRecord).includes(:employee, :leave_type).order(leave_date: :desc, id: :desc)
    scope = scope.where(leave_date: params[:leave_date]) if params[:leave_date].present?
    scope = scope.where(employee_id: params[:employee_id]) if params[:employee_id].present?
    records = scope.offset((page - 1) * per_page).limit(per_page)
    render json: { data: records.map { |record| leave_record_json(record) },
      meta: { page:, per_page:, total: scope.count } }
  end

  def show
    record = LeaveRecord.includes(:employee, :leave_type).find(params[:id])
    authorize record
    render json: { data: leave_record_json(record) }
  end

  private

  def page = [ params.fetch(:page, 1).to_i, 1 ].max
  def per_page = params.fetch(:per_page, DEFAULT_PER_PAGE).to_i.clamp(1, 100)

  def leave_record_json(record)
    employee = record.employee
    record.as_json(only: %i[id leave_date reason]).merge(
      "leave_type" => record.leave_type.name, "payroll_deduction" => record.payroll_deduction?,
      "employee" => { "id" => employee.id, "employee_id" => employee.employee_id,
        "name" => "#{employee.first_name} #{employee.last_name}" }
    )
  end
end
