module Leaves
  class GrantEntitlements
    def self.call(employee:, year:)
      LeaveType.where.not(default_entitlement: [ nil, 0 ]).find_each do |leave_type|
        grant(employee:, leave_type:, year:)
      end
    end

    def self.grant_all(employee_ids:, year:)
      entries = LeaveType.where.not(default_entitlement: [ nil, 0 ]).flat_map do |leave_type|
        employee_ids.map do |employee_id|
          LeaveLedgerEntry.new(employee_id:, leave_type:, year:, entry_type: "entitlement", days: leave_type.default_entitlement)
        end
      end
      LeaveLedgerEntry.import(entries, validate: false, on_duplicate_key_ignore: true)
    end

    def self.backfill(year:)
      Employee.find_each { |employee| call(employee:, year:) }
    end

    def self.grant(employee:, leave_type:, year:)
      LeaveLedgerEntry.find_or_create_by!(employee:, leave_type:, year:, entry_type: "entitlement") do |entry|
        entry.days = leave_type.default_entitlement
      end
    rescue ActiveRecord::RecordNotUnique
      # A concurrent grant already created this year's entitlement; the unique index keeps one.
    end
    private_class_method :grant
  end
end
