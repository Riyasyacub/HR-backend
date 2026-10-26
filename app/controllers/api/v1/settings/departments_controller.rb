class Api::V1::Settings::DepartmentsController < ApplicationController
  before_action :authenticate_user!
  after_action :verify_authorized

  def index
    authorize Department
    departments = Department.order(:name)
    render json: { data: departments.as_json(only: %i[id name code active]),
      meta: { page: 1, per_page: departments.size, total: departments.size } }
  end

  def create
    authorize Department
    department = Department.new(params.expect(department: %i[name code]))
    return render json: { data: department.as_json(only: %i[id name code active]) },
      status: :created if department.save

    render_validation_errors(department)
  end

  def update
    authorize department, :update?
    if department.update(params.expect(department: %i[name]))
      render json: { data: department.as_json(only: %i[id name code active]) }
    else
      render_validation_errors(department)
    end
  end

  def deactivate
    authorize department, :update?
    department.update!(active: false)
    render json: { data: department.as_json(only: %i[id name code active]) }
  end

  private

  def department
    @department ||= Department.find(params[:id])
  end

  def render_validation_errors(department)
    render_error(status: :unprocessable_content, code: "validation_failed",
      message: department.errors.full_messages.to_sentence,
      details: department.errors.full_messages)
  end
end
