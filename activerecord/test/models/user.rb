require 'models/job'

class User < ActiveRecord::Base
  has_secure_token
  has_secure_token :auth_token

  has_and_belongs_to_many :jobs_pool,
    class_name: Job,
    join_table: 'jobs_pool'
end
