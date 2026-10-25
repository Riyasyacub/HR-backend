class Api::V1::Auth::SessionsController < ApplicationController
  REFRESH_COOKIE = :refresh_token
  REFRESH_COOKIE_PATH = "/api/v1/auth"

  def create
    user = User.find_by(email: params[:email].to_s)
    unless user&.active? && user.authenticate(params[:password].to_s)
      return render_error(status: :unauthorized, code: "invalid_credentials",
        message: "Invalid email or password")
    end

    user_session, refresh_token = UserSession.start_for(user)
    set_refresh_cookie(refresh_token)

    render json: { data: sign_in_payload(user, user_session) }
  end

  def refresh
    user_session = refresh_session
    return invalid_refresh unless user_session

    raw_token = user_session.rotate!(cookies[REFRESH_COOKIE])
    return invalid_refresh unless raw_token

    set_refresh_cookie(raw_token)
    render json: { data: sign_in_payload(user_session.user, user_session) }
  end

  def destroy
    UserSession.find_by_token(cookies[REFRESH_COOKIE])&.revoke!
    clear_refresh_cookie
    head :no_content
  end

  private

  def refresh_session
    user_session = UserSession.find_by_token(cookies[REFRESH_COOKIE])
    return user_session if user_session&.active? && user_session.user.active?

    user_session&.revoke!
    nil
  end

  def invalid_refresh
    render_error(status: :unauthorized, code: "invalid_refresh_token",
      message: "Invalid refresh token")
  end

  def set_refresh_cookie(raw_token)
    cookies[REFRESH_COOKIE] = {
      value: raw_token,
      httponly: true,
      secure: Rails.env.production?,
      same_site: :lax,
      path: REFRESH_COOKIE_PATH,
      expires: Rails.configuration.x.session_inactivity_window.from_now
    }
  end

  def clear_refresh_cookie
    cookies.delete(REFRESH_COOKIE, path: REFRESH_COOKIE_PATH)
  end

  def sign_in_payload(user, user_session)
    {
      access_token: AccessToken.issue(user:, user_session:),
      token_type: "Bearer",
      expires_in: Rails.configuration.x.access_token_lifetime.to_i,
      user: user.as_json(only: %i[id name email country])
        .merge("role" => user.role.name)
    }
  end
end
