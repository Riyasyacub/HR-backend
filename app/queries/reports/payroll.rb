module Reports
  class Payroll
    AMOUNTS = %w[monthly_gross unpaid_deduction total].freeze

    def self.call(year:, filters: {})
      month = Arel.sql("TO_CHAR(payroll_runs.month, 'YYYY-MM')")
      PayrollLine.joins(:payroll_run).where(payroll_runs: { status: %w[generated paid], month: Date.new(year).all_year })
        .where(filters.compact_blank).group(month, :country, :currency).order(month, :country, :currency)
        .pluck(month, :country, :currency, Arel.sql("COUNT(*)"), *AMOUNTS.map { |amount| Arel.sql("SUM(payroll_lines.#{amount})") })
        .map do |month_label, country, currency, employees, *sums|
          { "month" => month_label, "country" => country, "currency" => currency, "employees" => employees,
            **AMOUNTS.zip(sums).to_h { |amount, sum| [ amount, format("%.2f", sum) ] } }
        end
    end
  end
end
