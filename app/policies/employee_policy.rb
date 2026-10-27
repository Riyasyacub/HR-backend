class EmployeePolicy < ApplicationPolicy
  SELF_SERVICE_ATTRIBUTES = %i[phone personal_email address emergency_contact].freeze

  def index? = true
  def create? = hr?
  def update? = hr? || record.user_id == user.id

  def permitted_attributes_for_update
    hr? ? Api::V1::EmployeesController::EMPLOYEE_ATTRIBUTES + SELF_SERVICE_ATTRIBUTES : SELF_SERVICE_ATTRIBUTES
  end

  def team? = user.manager?
  def show?
    hr? || record.user_id == user.id || manager_of_record?
  end

  private

  def manager_of_record?
    return false unless user.employee

    user.employee.subordinate_ids.include?(record.id)
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      return scope.all if user.hr?
      return scope.none unless user.employee
      return scope.where(id: user.employee.subordinate_ids) if user.manager?

      scope.all
    end

    private

    attr_reader :user, :scope
  end
end
