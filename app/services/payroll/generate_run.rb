module Payroll
  class GenerateRun
    class NotGeneratable < StandardError; end

    def self.call(run)
      run.with_lock do
        unless run.status == "draft" && run.calculation_status == "completed" && run.blocking_issues_count.zero?
          raise NotGeneratable, "Only a completed draft run without blocking issues can be generated"
        end

        freeze_employee_details(run)
        run.update!(status: "generated")
      end
    end

    def self.freeze_employee_details(run)
      run.payroll_lines.joins(:employee).update_all(<<~SQL.squish)
        employee_code = employees.employee_id, employee_name = employees.first_name || ' ' || employees.last_name,
        bank_name = employees.bank_name, ifsc = employees.ifsc, account_number = employees.account_number
      SQL
    end
    private_class_method :freeze_employee_details
  end
end
