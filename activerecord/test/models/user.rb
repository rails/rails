class User < ActiveRecord::Base
  has_secure_token
  has_secure_token :auth_token
end

class UserWithNotification < User
  after_create -> { Notification.create! message: "A new user has been created." }
end
