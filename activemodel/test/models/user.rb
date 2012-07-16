class User
  extend ActiveModel::Callbacks
  include ActiveModel::Validations
  include ActiveModel::SecurePassword
  
  define_model_callbacks :create

  has_secure_password

  attr_accessor :password_digest, :password_salt
end
