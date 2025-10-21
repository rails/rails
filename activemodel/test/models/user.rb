# frozen_string_literal: true

class User
  extend ActiveModel::Callbacks
  include ActiveModel::Attributes
  include ActiveModel::Dirty
  include ActiveModel::SecurePassword
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :name, :string

  define_model_callbacks :create

  attribute :password_digest
  has_secure_password

  attribute :recovery_password_digest
  has_secure_password :recovery_password, validations: false

  attr_accessor :password_called

  def password=(unencrypted_password)
    self.password_called ||= 0
    self.password_called += 1
    super
  end
end
