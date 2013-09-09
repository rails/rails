class Admin::Account < ApplicationRecord
  has_many :users
end