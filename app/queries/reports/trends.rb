module Reports
  class Trends
    START_MONTH = Arel.sql("TO_CHAR(employees.start_date, 'YYYY-MM')")
    LEAVE_MONTH = Arel.sql("TO_CHAR(leave_records.leave_date, 'YYYY-MM')")
    PAYROLL_MONTH = Arel.sql("TO_CHAR(payroll_runs.month, 'YYYY-MM')")

    def initialize(employees, months:, include_payroll:)
      @employees = employees.where(status: "active")
      @months = (0...months).map { |index| Date.current.beginning_of_month << (months - 1 - index) }
      @labels = @months.map { _1.strftime("%Y-%m") }
      @include_payroll = include_payroll
    end

    def call
      joiners = @employees.where(start_date: window).group(START_MONTH).count
      started_before = @employees.where(start_date: ...@months.first).count
      { "months" => @labels, "headcount" => @labels.map { started_before += joiners.fetch(_1, 0) },
        "joiners" => @labels.map { joiners.fetch(_1, 0) }, "leave_days" => series_by("leave_type", leave_days),
        "payroll_totals" => (series_by("currency", payroll_totals) { format("%.2f", _1) } if @include_payroll) }
    end

    private

    def window = @months.first..@months.last.end_of_month

    def leave_days
      LeaveRecord.joins(:leave_type).where(employee_id: @employees.select(:id), leave_date: window)
        .group(LEAVE_MONTH, "leave_types.name").count
    end

    def payroll_totals
      PayrollLine.joins(:payroll_run).where(payroll_runs: { status: %w[generated paid], month: @months.first..@months.last })
        .group(PAYROLL_MONTH, :currency).sum(:total)
    end

    def series_by(key, totals, &format_value)
      totals.keys.map(&:last).uniq.sort.map do |name|
        { key => name, "values" => @labels.map { (format_value || :itself.to_proc).call(totals.fetch([ _1, name ], 0)) } }
      end
    end
  end
end
