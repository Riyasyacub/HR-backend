module AuthenticationHelpers
  def authentication_headers(user)
    user_session, = UserSession.start_for(user)
    token = AccessToken.issue(user:, user_session:)
    { "Authorization" => "Bearer #{token}" }
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelpers, type: :request
end
