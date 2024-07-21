class User < ApplicationRecord
  has_secure_password validations: false
  has_many :sessions, dependent: :destroy

  validates :email_address, presence: true
end
