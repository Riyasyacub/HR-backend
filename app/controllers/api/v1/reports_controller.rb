class Api::V1::ReportsController < ApplicationController
  DEFAULT_PER_PAGE = 25

  before_action :authenticate_user!
  after_action :verify_authorized

  def headcount
    authorize :report, :headcount?
    unless Reports::Headcount::GROUPS.key?(params[:group_by])
      return render_error(status: :unprocessable_content, code: "invalid_group_by",
        message: "group_by must be one of #{Reports::Headcount::GROUPS.keys.join(', ')}")
    end

    rows = Reports::Headcount.call(policy_scope(Employee), group_by: params[:group_by],
      filters: params.permit(:country, :department_id).to_h)
    totals = { headcount: rows.sum { |row| row["headcount"] }, onboarding: rows.sum { |row| row["onboarding"] } }
    if request.format.xlsx?
      return send_report("headcount", [ params[:group_by].capitalize, "Headcount", "Onboarding" ],
        rows.map(&:values) + [ [ "Total", *totals.values ] ])
    end

    render json: { data: rows, meta: { group_by: params[:group_by], **totals } }
  end

  def joiners
    authorize :report, :joiners?
    period = requested_period
    return render_error(status: :unprocessable_content, code: "invalid_period", message: "from and to must be dates with from on or before to") unless period

    scope = Reports::Joiners.call(policy_scope(Employee), period:, filters: params.permit(:country, :department_id).to_h)
    if request.format.xlsx?
      return send_report("joiners", [ "Employee ID", "Name", "Country", "Department", "Start date" ],
        scope.joins(:department).pluck(:employee_id, Arel.sql("employees.first_name || ' ' || employees.last_name"),
          :country, "departments.name", :start_date))
    end

    render json: { data: scope.offset((page - 1) * per_page).limit(per_page).map { |employee| joiner_json(employee) },
      meta: { page:, per_page:, total: scope.count } }
  end

  def leave
    authorize :report, :leave?
    year = params.fetch(:year, Date.current.year).to_i
    employees = policy_scope(Employee).where(params.permit(:country, :department_id).to_h.compact_blank).order(:employee_id)
    report = Reports::Leave.new(employees, year:)
    return send_report("leave", report.export_headers, report.export_rows) if request.format.xlsx?

    render json: { data: report.rows(employees.offset((page - 1) * per_page).limit(per_page)),
      meta: { page:, per_page:, total: employees.count, year:, totals: report.totals } }
  end

  def payroll
    authorize :report, :payroll?
    year = params.fetch(:year, Date.current.year).to_i
    rows = Reports::Payroll.call(year:, filters: params.permit(:country).to_h)
    if request.format.xlsx?
      return send_report("payroll", [ "Month", "Country", "Currency", "Employees", "Monthly gross", "Unpaid deduction", "Total" ],
        rows.map { |row| [ *row.values_at("month", "country", "currency", "employees"), *Reports::Payroll::AMOUNTS.map { row[_1].to_d } ] })
    end

    render json: { data: rows, meta: { year: } }
  end

  private

  def send_report(name, headers, rows)
    send_data Reports::Sheet.to_xlsx(headers, rows), filename: "#{name}-#{Date.current.iso8601}.xlsx", type: Mime[:xlsx]
  end

  def page = [ params.fetch(:page, 1).to_i, 1 ].max
  def per_page = params.fetch(:per_page, DEFAULT_PER_PAGE).to_i.clamp(1, 100)

  def requested_period
    from, to = Date.iso8601(params[:from].to_s), Date.iso8601(params[:to].to_s)
    from..to if from <= to
  rescue Date::Error
    nil
  end

  def joiner_json(employee)
    employee.as_json(only: %i[id employee_id country start_date])
      .merge("name" => "#{employee.first_name} #{employee.last_name}", "department" => employee.department.name)
  end
end
