class User < ActiveRecord::Base
  has_secure_token
  has_secure_token :auth_token
end
