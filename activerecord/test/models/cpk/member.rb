# frozen_string_literal: true

module Cpk
  class Member < ActiveRecord::Base
    self.table_name = :cpk_members

    has_many :group_members
    has_many :groups, through: :group_members
    accepts_nested_attributes_for :group_members, allow_destroy: true
  end
  class MemberCustomFK < Member
    self.table_name = :cpk_members_custom_fk
    self.primary_key = :uuid
    has_many :group_members, class_name: "Cpk::GroupMemberCustomFK", foreign_key: :member_uuid, primary_key: :uuid
  end
end
