class Api::V1::PayrollRunsController < ApplicationController
  DEFAULT_PER_PAGE = 25

  before_action :authenticate_user!
  after_action :verify_authorized

  def index
    authorize PayrollRun
    runs = PayrollRun.order(month: :desc)
    render json: { data: runs.offset((page - 1) * per_page).limit(per_page).map { |run| run_json(run) },
      meta: { page:, per_page:, total: runs.count } }
  end

  def create
    authorize PayrollRun
    run = PayrollRun.create!(month: requested_month, created_by: current_user)
    CalculatePayrollRunJob.perform_later(run.id)
    render json: { data: run_json(run) }, status: :accepted
  rescue ActiveRecord::RecordInvalid => e
    render_error(status: :unprocessable_content, code: "validation_failed",
      message: e.record.errors.full_messages.to_sentence, details: e.record.errors.full_messages)
  end

  def show
    authorize PayrollRun
    run = PayrollRun.find(params[:id])
    render json: { data: run_json(run).merge("totals" => totals_json(run), "blocking_issues_count" => run.blocking_issues_count) }
  end

  def recalculate
    authorize PayrollRun
    run = PayrollRun.find(params[:id])
    requeued = PayrollRun.where(id: run.id, status: "draft", calculation_status: %w[completed failed])
      .update_all(calculation_status: "queued", calculation_error: nil, updated_at: Time.current)
    if requeued.zero?
      return render_error(status: :unprocessable_content, code: "not_recalculable",
        message: "Only a draft run that is not already calculating can be recalculated")
    end

    CalculatePayrollRunJob.perform_later(run.id)
    render json: { data: run_json(run.reload) }, status: :accepted
  end

  def generate
    authorize PayrollRun
    run = PayrollRun.find(params[:id])
    Payroll::GenerateRun.call(run)
    render json: { data: run_json(run) }
  rescue Payroll::GenerateRun::NotGeneratable => e
    render_error(status: :unprocessable_content, code: "not_generatable", message: e.message)
  end

  def export
    authorize PayrollRun
    run = PayrollRun.find(params[:id])
    if run.status == "draft"
      return render_error(status: :unprocessable_content, code: "not_exportable", message: "Generate the run before exporting it")
    end

    send_data Payroll::ExportSheet.to_xlsx(run), filename: "payroll-#{run.month.strftime('%Y-%m')}.xlsx",
      type: LeaveImport::XLSX_CONTENT_TYPE
  end

  def mark_paid
    authorize PayrollRun
    run = PayrollRun.find(params[:id])
    Payroll::MarkPaid.call(run, paid_on: requested_paid_on)
    render json: { data: run_json(run) }
  rescue Payroll::MarkPaid::NotPayable => e
    render_error(status: :unprocessable_content, code: "not_payable", message: e.message)
  end

  def lines
    authorize PayrollRun
    lines = PayrollRun.find(params[:id]).payroll_lines.preload(:employee).joins(:employee).order("employees.employee_id")
    lines = lines.where("jsonb_array_length(blocking_issues) > 0") if params[:issues_only] == "true"
    render json: { data: lines.offset((page - 1) * per_page).limit(per_page).map { |line| line_json(line) },
      meta: { page:, per_page:, total: lines.count } }
  end

  private

  def page = [ params.fetch(:page, 1).to_i, 1 ].max
  def per_page = params.fetch(:per_page, DEFAULT_PER_PAGE).to_i.clamp(1, 100)

  def requested_month
    Date.strptime(params[:month].to_s, "%Y-%m")
  rescue Date::Error
    nil
  end

  def requested_paid_on
    Date.iso8601(params[:paid_on].to_s)
  rescue Date::Error
    nil
  end

  def run_json(run)
    run.as_json(only: %i[id month status calculation_status calculation_error paid_on created_at])
  end

  def line_json(line)
    employee = line.employee
    line.as_json(only: %i[id country currency working_days unpaid_days blocking_issues]).merge(
      "employee" => { "id" => employee.id, "employee_id" => employee.employee_id,
        "name" => "#{employee.first_name} #{employee.last_name}" },
      **%w[monthly_gross unpaid_deduction total].index_with { |field| format("%.2f", line[field]) }
    )
  end

  def totals_json(run)
    run.country_currency_totals.map do |country, currency, employees, gross, deduction, total|
      { "country" => country, "currency" => currency, "employees" => employees, "monthly_gross" => format("%.2f", gross),
        "unpaid_deduction" => format("%.2f", deduction), "total" => format("%.2f", total) }
    end
  end
end
