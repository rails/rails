# frozen_string_literal: true

module Cpk
  class Group < ActiveRecord::Base
    self.table_name = :cpk_groups

    has_many :group_members
    has_many :members, through: :group_members
    accepts_nested_attributes_for :group_members, allow_destroy: true
  end
  class GroupCustomFK < Group
    self.primary_key = :id
    has_many :group_members, class_name: "Cpk::GroupMemberCustomFK", foreign_key: :group_id, primary_key: :id
    has_many :members, through: :group_members, class_name: "Cpk::MemberCustomFK"
    accepts_nested_attributes_for :group_members, allow_destroy: true
  end
end
