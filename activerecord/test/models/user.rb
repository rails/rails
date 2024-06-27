# frozen_string_literal: true

require "models/job"

class User < ActiveRecord::Base
  has_secure_password validations: false
  has_secure_password :recovery_password, validations: false

  has_secure_token
  has_secure_token :auth_token, length: 36

  has_and_belongs_to_many :jobs_pool,
    class_name: "Job",
    join_table: "jobs_pool"

  has_one :room
  has_one :owned_room, class_name: "Room", foreign_key: "owner_id"
  has_one :family_tree, -> { where(token: nil) }, foreign_key: "member_id"
  has_one :family, through: :family_tree
  has_many :family_members, through: :family, source: :members

  has_many :devices
  has_many :favorites,
           class_name: "User::Favorite"
  has_many :favorite_devices,
           through: :favorites,
           source: :favorable,
           source_type: "Device",
           class_name: "::Device"
  has_many :favorite_user_devices,
           through: :favorites,
           source: :favorable,
           source_type: "Device"
end

class UserWithNotification < User
  after_create -> { Notification.create! message: "A new user has been created." }
end

module Nested
  class User < ActiveRecord::Base
    self.table_name = "users"
  end
end
