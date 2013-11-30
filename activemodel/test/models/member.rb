class Member
  extend ActiveModel::Callbacks
  include ActiveModel::Validations
  include ActiveModel::SecurePassword
  
  define_model_callbacks :update, :create

  has_secure_password on: :update

  attr_accessor :password_digest, :password_salt
end
