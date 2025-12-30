# frozen_string_literal: true

class Pilot
  include ActiveModel::Attributes
  include ActiveModel::SecurePassword

  def self.generates_token_for(purpose, expires_in: nil, &)
    @@expires_in = expires_in
  end

  def self.find_by_token_for(purpose, token)
    "finding-for-#{purpose}-by-#{token}"
  end

  def self.find_by_token_for!(purpose, token)
    "finding-for-#{purpose}-by-#{token}!"
  end

  def generate_token_for(purpose)
    "#{purpose}-token-#{@@expires_in}"
  end

  attribute :password_digest
  has_secure_password
end
