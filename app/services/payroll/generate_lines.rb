module Payroll
  class GenerateLines
    def self.call(run)
      run.with_lock do
        if run.status == "draft"
          run.payroll_lines.delete_all
          eligible_employees(run.month).find_each do |employee|
            run.payroll_lines.create!(employee:, **CalculateLine.call(employee:, month: run.month))
          end
          run.update!(calculation_status: "completed", calculation_error: nil)
        end
      end
    end

    def self.eligible_employees(month)
      Employee.where(status: "active", start_date: ..month.end_of_month)
    end
    private_class_method :eligible_employees
  end
end
