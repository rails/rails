# frozen_string_literal: true

class SlowPilot
  include ActiveModel::SecurePassword

  def self.generates_token_for(purpose, expires_in: nil, &)
    @@expires_in = expires_in
  end

  def generate_token_for(purpose)
    "#{purpose}-token-#{@@expires_in}"
  end

  has_secure_password reset_token: { expires_in: 1.hour }
end
