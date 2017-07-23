require "active_storage/blob"
require "active_support/core_ext/module/delegation"

class ActiveStorage::Attachment < ActiveRecord::Base
  self.table_name = "active_storage_attachments"

  belongs_to :record, polymorphic: true
  belongs_to :blob, class_name: "ActiveStorage::Blob"

  delegate_missing_to :blob

  def purge
    blob.purge
    destroy
  end

  def purge_later
    ActiveStorage::PurgeJob.perform_later(self)
  end
end
