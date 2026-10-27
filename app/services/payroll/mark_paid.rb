module Payroll
  class MarkPaid
    class NotPayable < StandardError; end

    def self.call(run, paid_on:)
      raise NotPayable, "Paid date must be a date that is not in the future" if paid_on.nil? || paid_on > Date.current

      run.with_lock do
        raise NotPayable, "Only a generated run can be marked paid" unless run.status == "generated"

        run.update!(status: "paid", paid_on:)
      end
    end
  end
end
