require "active_vault/blob"
require "global_id"
require "active_support/core_ext/module/delegation"

# Schema: id, record_gid, blob_id, created_at
class ActiveVault::Attachment < ActiveRecord::Base
  self.table_name = "active_vault_attachments"

  belongs_to :blob, class_name: "ActiveVault::Blob"

  delegate_missing_to :blob

  def record
    @record ||= GlobalID::Locator.locate(record_gid)
  end

  def record=(record)
    @record = record
    self.record_gid = record&.to_gid
  end

  def purge
    blob.purge
    destroy
  end

  def purge_later
    ActiveVault::PurgeJob.perform_later(self)
  end
end
