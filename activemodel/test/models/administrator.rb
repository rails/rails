class Administrator
  include ActiveModel::Validations
  include ActiveModel::SecurePassword
  include ActiveModel::MassAssignmentSecurity

  attr_accessor :name, :password_digest
  attr_accessible :name

  has_secure_password
end
