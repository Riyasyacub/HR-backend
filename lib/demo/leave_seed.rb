module Demo
  class LeaveSeed
    SAMPLE_RATIO = 0.3
    TYPE_WEIGHTS = { "Earned" => 4, "Sick" => 3, "Casual" => 2, "Unpaid" => 1 }.freeze

    def self.call(today: Date.current) = new(today).call

    def initialize(today)
      @period = (today << 2)..today
      @working_days = @period.reject(&:on_weekend?)
      types = LeaveType.where(name: TYPE_WEIGHTS.keys).index_by(&:name)
      @weighted_types = TYPE_WEIGHTS.flat_map { |name, weight| Array.new(weight, types.fetch(name)) }
      @random = Random.new(7)
    end

    def call
      Employee.where(status: "active").in_batches(of: 1000).sum do |batch|
        employees = batch.order(:id).to_a.select { @random.rand < SAMPLE_RATIO }
        picks = employees.to_h { |employee| [ employee, pick_days(employee) ] }
        @working_days.map(&:year).uniq.each { Leaves::GrantEntitlements.grant_all(employee_ids: employees.map(&:id), year: _1) }
        LeaveRecord.transaction { insert(build_records(picks)) }
      end
    end

    private

    def pick_days(employee)
      eligible = @working_days.select { _1 >= employee.start_date }
      eligible.sample(@random.rand(1..4), random: @random).sort.map { [ _1, @weighted_types[@random.rand(@weighted_types.size)] ] }
    end

    def build_records(picks)
      ids = picks.keys.map(&:id)
      existing = LeaveRecord.where(employee_id: ids, leave_date: @period).pluck(:employee_id, :leave_date).to_set
      balances = LeaveLedgerEntry.where(employee_id: ids).group(:employee_id, :leave_type_id, :year).sum(:days)
      picks.flat_map do |employee, days|
        days.filter_map do |date, leave_type|
          next if existing.include?([ employee.id, date ])
          next if leave_type.balance_tracked? && !charge(balances, [ employee.id, leave_type.id, date.year ])

          LeaveRecord.new(employee_id: employee.id, leave_type:, leave_date: date, reason: "Demo seed")
        end
      end
    end

    def charge(balances, key)
      return false if balances.fetch(key, 0) < 1

      balances[key] -= 1
      true
    end

    def insert(records)
      LeaveRecord.import(records, validate: false)
      LeaveLedgerEntry.import(records.select { _1.leave_type.balance_tracked? }.map do |record|
        LeaveLedgerEntry.new(employee_id: record.employee_id, leave_type: record.leave_type, leave_record_id: record.id,
          year: record.leave_date.year, entry_type: "used", days: -1)
      end, validate: false)
      records.size
    end
  end
end
