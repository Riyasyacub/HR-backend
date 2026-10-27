class LeaveImportPolicy < ApplicationPolicy
  def create? = hr?
  def show? = hr?
  def template? = hr?
end
