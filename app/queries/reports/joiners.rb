module Reports
  class Joiners
    def self.call(scope, period:, filters: {})
      scope.where(start_date: period).where(filters.compact_blank).preload(:department).order(:start_date, :employee_id)
    end
  end
end
