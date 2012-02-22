class User
  include ActiveModel::Validations
  include ActiveModel::SecurePassword

  has_secure_password

  attr_accessor :password_digest, :password_salt
end

class Administrator
  include ActiveModel::Validations
  include ActiveModel::SecurePassword
  include ActiveModel::MassAssignmentSecurity

  has_secure_password

  attr_accessor :name, :password_digest
  attr_accessible :name
end

class Visitor
  include ActiveModel::Validations
  include ActiveModel::SecurePassword
  include ActiveModel::MassAssignmentSecurity

  has_secure_password

  attr_accessor :password_digest
end

class UserWithoutConfirmation
  include ActiveModel::Validations
  include ActiveModel::SecurePassword

  has_secure_password :without_confirmation => true

  attr_accessor :password_digest, :password_salt
end
