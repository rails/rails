class Visitor
  extend ActiveModel::Callbacks
  include ActiveModel::Validations
  include ActiveModel::SecurePassword
  include ActiveModel::MassAssignmentSecurity
  
  define_model_callbacks :create

  has_secure_password(validations: false)

  attr_accessor :password_digest, :password_confirmation
end
