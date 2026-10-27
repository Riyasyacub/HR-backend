class PayrollRun < ApplicationRecord
  STATUSES = %w[draft generated paid].freeze
  CALCULATION_STATUSES = %w[queued processing completed failed].freeze

  belongs_to :created_by, class_name: "User"
  has_many :payroll_lines, dependent: :destroy

  normalizes :month, with: ->(month) { month.beginning_of_month }

  validates :month, presence: true, uniqueness: true
  validates :status, inclusion: { in: STATUSES }
  validates :calculation_status, inclusion: { in: CALCULATION_STATUSES }

  def country_currency_totals
    payroll_lines.group(:country, :currency).order(:country, :currency)
      .pluck(:country, :currency, Arel.sql("COUNT(*)"), Arel.sql("SUM(monthly_gross)"),
        Arel.sql("SUM(unpaid_deduction)"), Arel.sql("SUM(total)"))
  end

  def blocking_issues_count
    payroll_lines.where("jsonb_array_length(blocking_issues) > 0").count
  end
end
