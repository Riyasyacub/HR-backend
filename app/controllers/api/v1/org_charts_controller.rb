class Api::V1::OrgChartsController < ApplicationController
  before_action :authenticate_user!
  after_action :verify_authorized

  def show
    authorize :org_chart, :show?
    render json: { data: OrgChartNodes.call(params[:manager_id] ? direct_reports : top_level) }
  end

  def path
    authorize :org_chart, :path?
    chain = visible_employees.find(params[:employee_id]).manager_chain_ids
    visible = visible_employees.where(id: chain).pluck(:id).to_set
    ids = chain.select { visible.include?(_1) }
    render json: { data: OrgChartNodes.call(Employee.where(id: ids), ordered_ids: ids) }
  end

  private

  def visible_employees = policy_scope(Employee, policy_scope_class: OrgChartPolicy::Scope)

  def direct_reports = visible_employees.where(manager_id: visible_employees.find(params[:manager_id]).id)

  def top_level = current_user.hr? ? Employee.where(manager_id: nil) : Employee.where(id: current_user.employee.id)
end
