class AssistantQueryPolicy < ApplicationPolicy
  def index? = AssistantPolicy.new(user, :assistant).create?

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve = scope.where(user:)

    private

    attr_reader :user, :scope
  end
end
