class LeaveTypePolicy < ApplicationPolicy
  def index? = hr?
  def update? = hr?
end
