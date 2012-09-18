class Administrator
  extend ActiveModel::Callbacks
  include ActiveModel::Validations
  include ActiveModel::SecurePassword

  define_model_callbacks :create

  attr_accessor :name, :password_digest

  has_secure_password
end
