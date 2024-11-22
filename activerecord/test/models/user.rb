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

  has_one :let_room, class_name: "Room", foreign_key: "landlord_id", dependent: :destroy
  has_one :rented_room, class_name: "Room", foreign_key: "tenant_id", dependent: :destroy
end

class UserWithNotification < User
  after_create -> { Notification.create! message: "A new user has been created." }
end

module Nested
  class User < ActiveRecord::Base
    self.table_name = "users"
  end

  class NestedUser < ActiveRecord::Base
    has_many :nested_users
  end
end
