class Session < ApplicationRecord
  has_secure_token
  belongs_to :user
end
