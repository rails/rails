class AuthUser
  extend ActiveModel::Callbacks
  include ActiveModel::Validations
  include ActiveModel::SecurePassword
  include ActiveModel::MassAssignmentSecurity

  define_model_callbacks :create

  has_secure_password :encrypted_attribute => :encrypted_password, :password_attribute => :pw

  attr_accessor :encrypted_password
end
