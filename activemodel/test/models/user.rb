# frozen_string_literal: true

class User
  extend ActiveModel::Callbacks
  include ActiveModel::SecurePassword

  define_model_callbacks :create

  has_secure_password
  has_secure_password :recovery_password, validations: false

  attr_accessor :password_digest, :recovery_password_digest
end
