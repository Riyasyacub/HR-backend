class Api::V1::EmployeesController < ApplicationController
  DEFAULT_PER_PAGE = 25
  EMPLOYEE_ATTRIBUTES = %i[employee_id first_name last_name work_email country department_id
    job_title start_date bank_name ifsc account_number status manager_id].freeze
  UPDATE_ATTRIBUTES = %i[manager_id department_id job_title status].freeze

  before_action :authenticate_user!
  after_action :verify_authorized

  def index
    authorize Employee
    employees = Employee.includes(:department, :manager).order(:employee_id)
      .offset((page - 1) * per_page).limit(per_page)
    render json: { data: employees.map { |employee| employee_json(employee) },
      meta: { page:, per_page:, total: Employee.count } }
  end

  def show
    authorize employee
    render json: { data: employee_detail_json(employee) }
  end

  def team
    authorize Employee
    ids = current_user.employee.subordinate_ids
    employees = Employee.includes(:department, :manager).where(id: ids).order(:employee_id)
    render json: { data: employees.map { |e| employee_json(e) } }
  end

  def update
    authorize employee
    employee.update!(params.expect(employee: UPDATE_ATTRIBUTES))
    render json: { data: employee_detail_json(employee.reload) }
  rescue ActiveRecord::RecordInvalid => e
    render_error(status: :unprocessable_content, code: "validation_failed",
      message: e.record.errors.full_messages.to_sentence,
      details: e.record.errors.full_messages)
  end

  def create
    authorize Employee
    employee = Employees::Create.call(
      employee_attributes: params.expect(employee: EMPLOYEE_ATTRIBUTES),
      compensation_attributes: params.expect(
        compensation: [ { components: [ %i[name annual_amount] ] } ]
      )
    )
    render json: {
      data: employee_json(employee).merge("compensation" => compensation_json(employee))
    }, status: :created
  rescue Employees::Create::Invalid => e
    render_error(status: :unprocessable_content, code: "validation_failed",
      message: e.message, details: [ e.message ])
  rescue ActiveRecord::RecordInvalid => e
    render_error(status: :unprocessable_content, code: "validation_failed",
      message: e.record.errors.full_messages.to_sentence,
      details: e.record.errors.full_messages)
  end

  private

  def employee
    @employee ||= Employee.includes(:department, :manager).find(params[:id])
  end

  def page
    [ params.fetch(:page, 1).to_i, 1 ].max
  end

  def per_page
    params.fetch(:per_page, DEFAULT_PER_PAGE).to_i.clamp(1, 100)
  end

  def employee_json(employee)
    employee.as_json(only: %i[id employee_id first_name last_name work_email country currency
      job_title start_date status])
      .merge(
        "department" => { "id" => employee.department_id,
          "name" => employee.department.name },
        "manager" => manager_json(employee.manager)
      )
  end

  def manager_json(manager)
    return unless manager

    {
      "id" => manager.id,
      "employee_id" => manager.employee_id,
      "name" => "#{manager.first_name} #{manager.last_name}".strip
    }
  end

  def employee_detail_json(employee)
    json = employee_json(employee)
    return json unless current_user.hr? || employee.user_id == current_user.id

    json.merge(
      "bank" => employee.as_json(only: %i[bank_name ifsc account_number]),
      "compensation" => compensation_json(employee)
    )
  end

  def compensation_json(employee)
    compensation = employee.compensations.order(:effective_date).last
    return unless compensation

    {
      "id" => compensation.id,
      "effective_date" => compensation.effective_date,
      "annual_ctc" => format("%.2f", compensation.annual_ctc),
      "currency" => compensation.currency,
      "components" => compensation.components.order(:id).map do |component|
        { "id" => component.id, "name" => component.name,
          "annual_amount" => format("%.2f", component.annual_amount) }
      end
    }
  end
end
