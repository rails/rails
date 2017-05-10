class Visitor
  extend ActiveModel::Callbacks
  include ActiveModel::SecurePassword

  define_model_callbacks :create

  has_secure_password(validations: false, password_field: :astalavista)

  attr_accessor :astalavista_digest
end
