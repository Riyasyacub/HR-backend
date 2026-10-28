class ReportPolicy < ApplicationPolicy
  def headcount? = hr? || user.manager?
  def joiners? = headcount?
  def leave? = headcount?
  def payroll? = hr?
  def trends? = headcount?
end
