class User < ApplicationRecord
  has_secure_password validations: false
  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: -> { _1.strip.downcase }
end
