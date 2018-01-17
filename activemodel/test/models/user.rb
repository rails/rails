# frozen_string_literal: true

class User
  extend ActiveModel::Callbacks
  include ActiveModel::SecurePassword

  define_model_callbacks :create

  has_secure_password

  attr_accessor :password_digest
end
