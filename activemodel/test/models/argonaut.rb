# frozen_string_literal: true

class Argonaut
  include ActiveModel::SecurePassword
  include ActiveModel::Attributes

  attribute :password_digest
  has_secure_password algorithm: :argon2
end
