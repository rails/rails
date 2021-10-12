# frozen_string_literal: true

class DestroyAsyncParentSoftDelete < ActiveRecord::Base
  has_many :taggings, as: :taggable, class_name: "Tagging"
  has_many :tags, through: :taggings,
    dependent: :destroy_async,
    ensuring_owner_was: :deleted?

  has_one :dl_keyed_has_one, dependent: :destroy_async,
    ensuring_owner_was: :deleted?

  def deleted?
    deleted
  end

  def destroy
    update(deleted: true)
    run_callbacks(:destroy)
  end
end
