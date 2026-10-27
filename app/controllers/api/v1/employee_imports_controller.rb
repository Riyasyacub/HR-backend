class Api::V1::EmployeeImportsController < ApplicationController
  before_action :authenticate_user!
  after_action :verify_authorized

  def create
    authorize EmployeeImport
    employee_import = EmployeeImport.create!(uploaded_by: current_user, file: params[:file], mode: params.fetch(:mode, "create"))
    ImportEmployeeSheetJob.perform_later(employee_import.id)
    render json: { data: employee_import_json(employee_import) }, status: :accepted
  rescue ActiveRecord::RecordInvalid => e
    render_error(status: :unprocessable_content, code: "validation_failed",
      message: e.record.errors.full_messages.to_sentence, details: e.record.errors.full_messages)
  end

  def show
    authorize EmployeeImport
    employee_import = EmployeeImport.find(params[:id])
    errors_page = [ params.fetch(:errors_page, 1).to_i, 1 ].max
    errors_per_page = params.fetch(:errors_per_page, 50).to_i.clamp(1, 200)
    page_of_errors = employee_import.row_errors.slice((errors_page - 1) * errors_per_page, errors_per_page) || []
    render json: { data: employee_import_json(employee_import).merge("row_errors" => page_of_errors),
      meta: { row_errors_total: employee_import.row_errors.size, errors_page:, errors_per_page: } }
  end

  def template
    authorize EmployeeImport
    send_data Employees::Template.to_xlsx, filename: "employee_template.xlsx", type: Mime[:xlsx]
  end

  private

  def employee_import_json(employee_import)
    employee_import.as_json(only: %i[id mode status total_rows imported_rows row_errors error_message created_at])
  end
end
