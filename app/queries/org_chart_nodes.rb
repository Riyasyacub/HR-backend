class OrgChartNodes
  REPORTS_COUNT = "(SELECT COUNT(*) FROM employees reports WHERE reports.manager_id = employees.id) AS reports_count".freeze

  def self.call(employees, ordered_ids: nil)
    loaded = employees.preload(:department).select("employees.*", REPORTS_COUNT).order(:first_name, :last_name, :employee_id).to_a
    loaded = loaded.sort_by { ordered_ids.index(_1.id) } if ordered_ids
    loaded.map do |employee|
      { "id" => employee.id, "employee_id" => employee.employee_id, "name" => "#{employee.first_name} #{employee.last_name}",
        "job_title" => employee.job_title, "department" => employee.department.name, "reports_count" => employee.reports_count }
    end
  end
end
