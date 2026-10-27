class LeaveRecord < ApplicationRecord
  belongs_to :employee
  belongs_to :leave_type
  belongs_to :leave_import, optional: true

  validates :leave_date, presence: true, uniqueness: { scope: :employee_id }
  validate :leave_date_on_working_day
  validate :leave_date_within_employment

  def payroll_deduction?
    leave_type.name == "Unpaid"
  end

  private

  def leave_date_on_working_day
    errors.add(:leave_date, "must be a working day") if leave_date&.on_weekend?
  end

  def leave_date_within_employment
    return unless leave_date && employee && leave_date < employee.start_date

    errors.add(:leave_date, "is before the employee's start date")
  end
end
