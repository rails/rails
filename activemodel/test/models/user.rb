class User
  extend ActiveModel::Callbacks
  include ActiveModel::Validations
  include ActiveModel::SecurePassword
  
  define_model_callbacks :create

  has_secure_password validations: { unless: :skip_hsp_validations }

  attr_accessor :password_digest, :skip_hsp_validations
end
