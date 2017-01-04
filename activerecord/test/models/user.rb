class User < ActiveRecord::Base
  has_many :user_businesses
  has_many :businesses, through: :user_businesses
end
