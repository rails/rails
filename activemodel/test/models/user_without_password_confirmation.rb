class UserWithoutPasswordConfirmation
  include ActiveModel::Validations
  include ActiveModel::SecurePassword

  has_secure_password :password_confirmation => false

  attr_accessor :password_digest, :password_salt
end
