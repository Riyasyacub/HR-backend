class UserSession < ApplicationRecord
  belongs_to :user

  scope :active, -> { where(revoked_at: nil) }

  class << self
    def start_for(user, now: Time.current)
      raw_token = SecureRandom.urlsafe_base64(48)
      session = create!(user:, refresh_token_digest: digest(raw_token), last_used_at: now)
      [ session, raw_token ]
    end

    def find_by_token(raw_token)
      find_by(refresh_token_digest: digest(raw_token)) if raw_token.present?
    end

    def digest(raw_token)
      Digest::SHA256.hexdigest(raw_token)
    end
  end

  def rotate!(raw_token = nil, now: Time.current)
    with_lock do
      next unless active?(now:)
      next if raw_token && refresh_token_digest != self.class.digest(raw_token)

      new_token = SecureRandom.urlsafe_base64(48)
      update!(refresh_token_digest: self.class.digest(new_token), last_used_at: now)
      new_token
    end
  end

  def active?(now: Time.current)
    revoked_at.nil? && last_used_at > now - Rails.configuration.x.session_inactivity_window
  end

  def record_activity!(now: Time.current)
    update!(last_used_at: now)
  end

  def revoke!
    update!(revoked_at: Time.current)
  end
end
