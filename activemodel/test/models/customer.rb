class Customer
  include ActiveModel::Validations
  include ActiveModel::SecurePassword

  has_secure_password :allow_nil => true

  attr_accessor :password_digest, :password_salt
end
