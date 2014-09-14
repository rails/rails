class User < ActiveRecord::Base
  has_secure_key :secure_key
end
