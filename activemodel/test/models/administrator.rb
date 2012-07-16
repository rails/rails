class Administrator
  extend ActiveModel::Callbacks
  include ActiveModel::Validations
  include ActiveModel::SecurePassword
  include ActiveModel::MassAssignmentSecurity
  
  define_model_callbacks :create

  attr_accessor :name, :password_digest
  attr_accessible :name

  has_secure_password
end
