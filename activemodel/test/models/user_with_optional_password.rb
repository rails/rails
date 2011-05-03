class UserWithOptionalPassword
  include ActiveModel::Validations
  include ActiveModel::SecurePassword

  has_secure_password :required => false

  attr_accessor :password_digest
end
