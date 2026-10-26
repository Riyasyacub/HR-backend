class EmployeePolicy < ApplicationPolicy
  def index? = hr?
  def create? = hr?
  def show? = hr? || record.user_id == user.id
end
