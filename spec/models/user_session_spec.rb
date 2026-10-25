require "rails_helper"

RSpec.describe UserSession, type: :model do
  let(:user) { create(:user) }

  it "starts a session with a random refresh token and stores only its digest" do
    session, raw_token = described_class.start_for(user)

    expect(raw_token).to be_present
    expect(session.refresh_token_digest).to eq(Digest::SHA256.hexdigest(raw_token))
    expect(session.refresh_token_digest).not_to eq(raw_token)
    expect(session.last_used_at).to be_within(1.second).of(Time.current)
    expect(user.user_sessions).to include(session)
  end

  it "finds the session by the raw refresh token" do
    session, raw_token = described_class.start_for(user)

    expect(described_class.find_by_token(raw_token)).to eq(session)
    expect(described_class.find_by_token("not-a-token")).to be_nil
    expect(described_class.find_by_token(nil)).to be_nil
    expect(described_class.find_by_token("")).to be_nil
  end

  it "rotates the refresh token and invalidates the previous one" do
    session, previous_token = described_class.start_for(user)

    new_token = session.rotate!(previous_token)

    expect(new_token).not_to eq(previous_token)
    expect(described_class.find_by_token(previous_token)).to be_nil
    expect(described_class.find_by_token(new_token)).to eq(session)
  end

  it "rotates only once for the same refresh token" do
    session, token = described_class.start_for(user)

    new_token = session.rotate!(token)

    expect(session.rotate!(token)).to be_nil
    expect(described_class.find_by_token(new_token)).to eq(session)
  end

  it "does not rotate an expired session" do
    session, token = described_class.start_for(user)

    travel 61.seconds do
      expect(session.rotate!(token)).to be_nil
    end
  end

  it "expires after the configured inactivity window" do
    session, = described_class.start_for(user)

    travel 61.seconds do
      expect(session).not_to be_active
    end
  end

  it "revokes only the session it is called on" do
    session, = described_class.start_for(user)
    other_session, = described_class.start_for(user)

    session.revoke!

    expect(session).not_to be_active
    expect(other_session).to be_active
  end
end
