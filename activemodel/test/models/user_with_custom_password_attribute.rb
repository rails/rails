class UserWithCustomPasswordAttribute
  include ActiveModel::Validations
  include ActiveModel::SecurePassword

  has_secure_password :encrypted_password

  attr_accessor :encrypted_password
end
