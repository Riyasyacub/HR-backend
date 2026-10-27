module Employees
  class ImportCompensation
    def self.call(imported, effective_date: nil)
      compensations = imported.map do |pair|
        Compensation.new(employee_id: pair.employee.id, currency: pair.employee.currency,
          effective_date: effective_date || pair.employee.start_date, annual_ctc: pair.row.components.sum { _1[:annual_amount] })
      end
      Compensation.import(compensations, validate: false)
      components = imported.zip(compensations).flat_map do |pair, compensation|
        pair.row.components.map { |component| CompensationComponent.new(compensation_id: compensation.id, **component) }
      end
      CompensationComponent.import(components, validate: false)
    end
  end
end
