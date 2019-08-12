# frozen_string_literal: true

class DlKeyedBelongsTo < ActiveRecord::Base
  self.primary_key = "belongs_key"
  belongs_to :destory_later_parent, dependent: :destroy_later, foreign_key: :destroy_later_parent_id, primary_key: :parent_id, class_name: "DestroyLaterParent"
  belongs_to :destory_later_parent_soft_delete,
    dependent: :destroy_later,
    owner_ensuring_destroy: :deleted?, class_name: "DestroyLaterParentSoftDelete"
end
