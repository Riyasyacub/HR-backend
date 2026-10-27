module Employees
  class MapManagers
    def self.call(imported) = new.call(imported)

    def call(imported)
      with_manager = imported.select { _1.row.manager_employee_id }
      manager_ids = Employee.where(employee_id: with_manager.map { _1.row.manager_employee_id }).pluck(:employee_id, :id).to_h
      @tree = Employee.pluck(:id, :manager_id).to_h
      row_errors = []
      assignments = with_manager.filter_map do |pair|
        manager_id = manager_ids[pair.row.manager_employee_id]
        error = assignment_error(pair, manager_id)
        if error
          row_errors << { "line" => pair.row.line, "errors" => [ error ] }
          next
        end

        @tree[pair.employee.id] = manager_id
        [ pair.employee.id, manager_id ]
      end
      assignments.group_by(&:last).each { |manager_id, pairs| Employee.where(id: pairs.map(&:first)).update_all(manager_id:, updated_at: Time.current) }
      row_errors
    end

    private

    def assignment_error(pair, manager_id)
      return "unknown manager #{pair.row.manager_employee_id}" unless manager_id
      return "employee cannot manage themselves" if manager_id == pair.employee.id

      "manager #{pair.row.manager_employee_id} creates a reporting cycle" if reports_to?(manager_id, pair.employee.id)
    end

    def reports_to?(employee_id, ancestor_id)
      seen = Set.new
      while employee_id && seen.add?(employee_id)
        return true if employee_id == ancestor_id

        employee_id = @tree[employee_id]
      end
      false
    end
  end
end
