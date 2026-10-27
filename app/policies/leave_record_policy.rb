class LeaveRecordPolicy < ApplicationPolicy
  def index? = true
  def show? = Scope.new(user, LeaveRecord).resolve.exists?(record.id)

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      return scope.all if user.hr?
      return scope.none unless user.employee

      scope.where(employee_id: [ user.employee.id, *user.employee.subordinate_ids ])
    end

    private

    attr_reader :user, :scope
  end
end
