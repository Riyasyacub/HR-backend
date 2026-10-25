require "rails_helper"

RSpec.describe AccessToken do
  let(:user) { create(:user, :hr) }
  let(:user_session) { UserSession.start_for(user).first }

  it "issues a signed token with identity, role, version, and session claims" do
    token = described_class.issue(user:, user_session:)
    payload = described_class.decode(token)
    _, header = JWT.decode(token, nil, false)

    expect(header["alg"]).to eq("HS256")
    expect(payload).to include(
      "sub" => user.id.to_s,
      "role" => Role::HR,
      "ver" => user.token_version,
      "sid" => user_session.id,
      "typ" => "access",
      "iss" => AccessToken::ISSUER,
      "aud" => AccessToken::AUDIENCE
    )
    expect(payload["exp"] - payload["iat"]).to eq(15.minutes.to_i)
  end

  it "rejects an expired token" do
    token = described_class.issue(user:, user_session:)

    travel 16.minutes do
      expect { described_class.decode(token) }.to raise_error(AccessToken::InvalidToken)
    end
  end

  it "rejects a tampered token" do
    token = described_class.issue(user:, user_session:)

    expect { described_class.decode("#{token}tampered") }.to raise_error(AccessToken::InvalidToken)
  end

  it "rejects a token with the wrong issuer" do
    token = described_class.issue(user:, user_session:)
    payload, = JWT.decode(token, nil, false)
    forged = JWT.encode(payload.merge("iss" => "other-issuer"), described_class.send(:secret), "HS256")

    expect { described_class.decode(forged) }.to raise_error(AccessToken::InvalidToken, /issuer/i)
  end

  it "rejects a token with the wrong audience" do
    token = described_class.issue(user:, user_session:)
    payload, = JWT.decode(token, nil, false)
    forged = JWT.encode(payload.merge("aud" => "other-audience"), described_class.send(:secret), "HS256")

    expect { described_class.decode(forged) }.to raise_error(AccessToken::InvalidToken, /audience/i)
  end
end
