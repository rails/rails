# frozen_string_literal: true

class Visitor
  extend ActiveModel::Callbacks
  include ActiveModel::SecurePassword

  define_model_callbacks :create

  has_secure_password(validations: false)

  attr_accessor :password_digest, :password_confirmation
end
