class User
  extend ActiveModel::Callbacks
  include ActiveModel::Validations
  include ActiveModel::SecurePassword
  include ActiveModel::OneTimePassword

  define_model_callbacks :create

  has_secure_password
  has_one_time_password

  attr_accessor :password_digest, :password_salt, :otp_secret_key, :email
end
