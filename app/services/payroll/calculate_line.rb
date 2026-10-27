module Payroll
  class CalculateLine
    def self.call(employee:, month:) = new(employee:, month:).call

    def initialize(employee:, month:)
      @employee = employee
      @month = month.beginning_of_month..month.end_of_month
    end

    def call
      gross = monthly_gross
      deduction = unpaid_days.zero? ? 0 : (gross / working_days * unpaid_days).round(2)
      { country: employee.country, currency: employee.currency, monthly_gross: gross, working_days:,
        unpaid_days:, unpaid_deduction: deduction, total: gross - deduction, blocking_issues: }
    end

    private

    attr_reader :employee, :month

    def compensation
      @compensation ||= employee.current_compensation(month.end)
    end

    def monthly_gross
      return BigDecimal(0) unless compensation

      (compensation.components.sum(:annual_amount) / 12).round(2)
    end

    def working_days
      @working_days ||= month.count { |day| !day.on_weekend? }
    end

    def unpaid_days
      @unpaid_days ||= employee.leave_records.joins(:leave_type)
        .where(leave_date: month, leave_types: { name: "Unpaid" }).count
    end

    def blocking_issues
      [
        ("missing bank name" if employee.bank_name.blank?),
        ("missing account number" if employee.account_number.blank?),
        ("missing compensation components" unless compensation&.components&.exists?)
      ].compact
    end
  end
end
