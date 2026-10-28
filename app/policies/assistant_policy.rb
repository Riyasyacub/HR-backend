class AssistantPolicy < ApplicationPolicy
  def create? = hr? || user.employee.present?

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      return scope.all if user.hr?
      return scope.none unless user.employee

      scope.where(id: [ user.employee.id, *user.employee.subordinate_ids ])
    end

    private

    attr_reader :user, :scope
  end
end
