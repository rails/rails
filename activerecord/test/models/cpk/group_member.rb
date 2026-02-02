# frozen_string_literal: true

module Cpk
  class GroupMember < ActiveRecord::Base
    self.table_name = :cpk_groups_members

    belongs_to :group
    belongs_to :member

    validates :member, uniqueness: { scope: :group_id }
  end
  class GroupMemberCustomFK < GroupMember
    self.table_name = :cpk_groups_members_custom_fk
    self.primary_key = [:group_id, :member_uuid]

    belongs_to :group, class_name: "GroupCustomFK", foreign_key: :group_id, primary_key: :id
    belongs_to :member, class_name: "MemberCustomFK", foreign_key: :member_uuid, primary_key: :uuid
  end
end
