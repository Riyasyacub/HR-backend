class EmployeePolicy < ApplicationPolicy
  def index? = hr?
  def create? = hr?
  def update? = hr?
  def team? = user.manager?
  def show?
    hr? || record.user_id == user.id || manager_of_record?
  end

  private

  def manager_of_record?
    return false unless user.employee

    user.employee.subordinate_ids.include?(record.id)
  end
end
