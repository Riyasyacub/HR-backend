class ApplicationController < ActionController::API
  include ActionController::Cookies
  include Pundit::Authorization

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  attr_reader :current_user, :current_user_session

  def authenticate_user!
    payload = AccessToken.decode(bearer_token)
    @current_user = User.find_by(id: payload["sub"])
    @current_user_session = @current_user&.user_sessions&.find_by(id: payload["sid"])
    return invalid_token unless valid_access_token?(payload)

    @current_user_session.record_activity!
  rescue AccessToken::InvalidToken
    invalid_token
  end

  def valid_access_token?(payload)
    @current_user&.active? &&
      @current_user_session&.active? &&
      payload["ver"] == @current_user.token_version
  end

  def bearer_token
    request.headers["Authorization"].to_s[/\ABearer (.+)\z/i, 1].presence ||
      raise(AccessToken::InvalidToken, "missing bearer token")
  end

  def invalid_token
    render_error(status: :unauthorized, code: "invalid_token",
      message: "Invalid access token")
  end

  def user_not_authorized
    render_error(status: :forbidden, code: "forbidden", message: "You are not authorized to perform this action")
  end

  def render_error(status:, code:, message:, details: [])
    render json: { error: { code:, message:, details: } }, status:
  end
end
