class Admin::Account < ActiveRecord::Base
  has_many :users
end