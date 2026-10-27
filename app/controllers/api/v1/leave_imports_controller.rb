class Api::V1::LeaveImportsController < ApplicationController
  before_action :authenticate_user!
  after_action :verify_authorized

  def create
    authorize LeaveImport
    leave_import = LeaveImport.create!(uploaded_by: current_user, file: params[:file])
    ImportLeaveSheetJob.perform_later(leave_import.id)
    render json: { data: leave_import_json(leave_import) }, status: :accepted
  rescue ActiveRecord::RecordInvalid => e
    render_error(status: :unprocessable_content, code: "validation_failed",
      message: e.record.errors.full_messages.to_sentence, details: e.record.errors.full_messages)
  end

  def show
    authorize LeaveImport
    render json: { data: leave_import_json(LeaveImport.find(params[:id])) }
  end

  def template
    authorize LeaveImport
    send_data Leaves::Template.to_xlsx, filename: "leave_template.xlsx", type: LeaveImport::XLSX_CONTENT_TYPE
  end

  private

  def leave_import_json(leave_import)
    leave_import.as_json(only: %i[id status total_rows imported_rows row_errors error_message created_at])
  end
end
