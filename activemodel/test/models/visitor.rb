class Visitor
  extend ActiveModel::Callbacks
  include ActiveModel::Validations
  include ActiveModel::SecurePassword

  define_model_callbacks :create

  has_secure_password(validations: false, column_name: :password)

  attr_accessor :password, :password_confirmation
end
