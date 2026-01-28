# frozen_string_literal: true

module Cpk
  class GroupMember < ActiveRecord::Base
    self.table_name = :cpk_groups_members

    belongs_to :group
    belongs_to :member

    validates :member, uniqueness: { scope: :group_id }
  end
end
