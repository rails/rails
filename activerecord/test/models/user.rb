class User < ActiveRecord::Base
  has_secure_token
  has_secure_token :auth_token
  has_secure_token :conditional_token, if: :token_condition

  attr_accessor :token_condition
end

class UserWithNotification < User
  after_create -> { Notification.create! message: "A new user has been created." }
end
