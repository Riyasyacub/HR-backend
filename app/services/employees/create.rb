module Employees
  class Create
    class Invalid < StandardError; end

    def self.call(employee_attributes:, compensation_attributes:)
      new(employee_attributes:, compensation_attributes:).call
    end

    def initialize(employee_attributes:, compensation_attributes:)
      @employee_attributes = employee_attributes.to_h.symbolize_keys
      @compensation_attributes = compensation_attributes.to_h.symbolize_keys
    end

    def call
      components = compensation_attributes.fetch(:components, [])
        .map { |component| component.to_h.symbolize_keys }
      raise Invalid, "at least one compensation component is required" if components.empty?
      raise Invalid, "annual CTC is derived from components" if compensation_attributes.key?(:annual_ctc)

      Employee.transaction do
        employee = Employee.create!(employee_attributes)
        employee.compensations.create!(
          compensation_attributes.except(:components).merge(components_attributes: components)
        )
        employee
      end
    end

    private

    attr_reader :employee_attributes, :compensation_attributes
  end
end
