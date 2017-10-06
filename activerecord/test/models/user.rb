# frozen_string_literal: true

require "models/job"

class User < ActiveRecord::Base
  has_secure_token
  has_secure_token :auth_token

  has_and_belongs_to_many :jobs_pool,
    class_name: "Job",
    join_table: "jobs_pool"

  has_one :family_tree, -> { where(token: nil) }, foreign_key: "member_id"
  has_one :family, through: :family_tree
  has_many :family_members, through: :family, source: :members
end

class UserWithNotification < User
  after_create -> { Notification.create! message: "A new user has been created." }
end
