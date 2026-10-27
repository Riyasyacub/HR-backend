class PayrollRunPolicy < ApplicationPolicy
  def index? = hr?
  def create? = hr?
  def show? = hr?
  def recalculate? = hr?
  def lines? = hr?
end
