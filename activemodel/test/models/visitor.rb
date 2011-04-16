class Visitor
  include ActiveModel::Validations
  include ActiveModel::SecurePassword
  include ActiveModel::MassAssignmentSecurity

  has_secure_password :cost => 9

  attr_accessor :password_digest
end
