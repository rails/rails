# frozen_string_literal: true

require "models/destroy_later_parent_soft_delete"

class DlKeyedBelongsToSoftDelete < ActiveRecord::Base
  belongs_to :destory_later_parent_soft_delete,
    dependent: :destroy_later,
    owner_ensuring_destroy: :deleted?,
    class_name: "DestroyLaterParentSoftDelete"

  def deleted?
    deleted
  end

  def destroy
    update(deleted: true)
    run_callbacks(:destroy)
  end
end
