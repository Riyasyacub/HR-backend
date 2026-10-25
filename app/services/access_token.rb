class AccessToken
  ALGORITHM = "HS256"
  ISSUER = "incubyte-hr"
  AUDIENCE = "incubyte-hr-web"
  class InvalidToken < StandardError; end

  class << self
    def issue(user:, user_session:, now: Time.current)
      payload = {
        sub: user.id.to_s,
        role: user.role.name,
        ver: user.token_version,
        sid: user_session.id,
        typ: "access",
        iat: now.to_i,
        exp: (now + Rails.configuration.x.access_token_lifetime).to_i,
        iss: ISSUER,
        aud: AUDIENCE
      }

      JWT.encode(payload, secret, ALGORITHM)
    end

    def decode(token)
      payload, = JWT.decode(
        token,
        secret,
        true,
        algorithm: ALGORITHM,
        verify_iss: true,
        iss: ISSUER,
        verify_aud: true,
        aud: AUDIENCE
      )

      raise InvalidToken, "unexpected token type" unless payload["typ"] == "access"

      payload
    rescue JWT::DecodeError => error
      raise InvalidToken, error.message
    end

    private
    def secret
      Rails.application.credentials.dig(:jwt, :secret).presence || Rails.application.secret_key_base
    end
  end
end
