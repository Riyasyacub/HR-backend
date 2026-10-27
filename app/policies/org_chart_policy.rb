class OrgChartPolicy < ApplicationPolicy
  def show? = hr? || user.manager?
  def path? = show?

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      return scope.all if user.hr?
      return scope.none unless user.manager?

      scope.where(id: [ user.employee.id, *user.employee.subordinate_ids ])
    end

    private

    attr_reader :user, :scope
  end
end
