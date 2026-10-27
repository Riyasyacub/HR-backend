class PayrollLine < ApplicationRecord
  belongs_to :payroll_run
  belongs_to :employee

  validates :employee_id, uniqueness: { scope: :payroll_run_id }
  validates :country, :currency, :monthly_gross, :working_days, :unpaid_days, :unpaid_deduction, :total,
    presence: true
end
