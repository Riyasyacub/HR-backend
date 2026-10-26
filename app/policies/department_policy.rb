class DepartmentPolicy < ApplicationPolicy
  def index? = hr?
  def create? = hr?
  def update? = hr?
end
