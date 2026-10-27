class Api::V1::MeController < ApplicationController
  before_action :authenticate_user!

  def show
    render json: { data: { user: current_user.as_json(only: %i[id name email country])
      .merge("role" => current_user.role.name,
        "employee_id" => current_user.employee&.id,
        "is_manager" => current_user.manager?) } }
  end
end
