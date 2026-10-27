module Reports
  class Headcount
    GROUPS = {
      "country" => "employees.country",
      "department" => "departments.name",
      "manager" => "COALESCE(managers.first_name || ' ' || managers.last_name, 'No manager')"
    }.freeze

    def self.call(scope, group_by:, filters: {})
      group = Arel.sql(GROUPS.fetch(group_by))
      scope.where(filters.compact_blank).joins(:department)
        .joins("LEFT JOIN employees managers ON managers.id = employees.manager_id")
        .group(group).order(group)
        .pluck(group, Arel.sql("COUNT(*) FILTER (WHERE employees.status = 'active')"),
          Arel.sql("COUNT(*) FILTER (WHERE employees.status = 'onboarding')"))
        .map { |name, headcount, onboarding| { "group" => name, "headcount" => headcount, "onboarding" => onboarding } }
    end
  end
end
