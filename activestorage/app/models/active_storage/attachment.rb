# frozen_string_literal: true

require "active_support/core_ext/module/delegation"

# Attachments associate records with blobs. Usually that's a one record-many blobs relationship,
# but it is possible to associate many different records with the same blob. A foreign-key constraint
# on the attachments table prevents blobs from being purged if they’re still attached to any records.
class ActiveStorage::Attachment < ActiveRecord::Base
  self.table_name = "active_storage_attachments"

  belongs_to :record, polymorphic: true, touch: true
  belongs_to :blob, class_name: "ActiveStorage::Blob"

  delegate_missing_to :blob

  after_create_commit :analyze_blob_later, :identify_blob
  after_destroy_commit :purge_dependent_blob_later

  # Synchronously deletes the attachment and {purges the blob}[rdoc-ref:ActiveStorage::Blob#purge].
  def purge
    delete
    blob&.purge
  end

  # Deletes the attachment and {enqueues a background job}[rdoc-ref:ActiveStorage::Blob#purge_later] to purge the blob.
  def purge_later
    delete
    blob&.purge_later
  end

  private
    def identify_blob
      blob.identify
    end

    def analyze_blob_later
      blob.analyze_later unless blob.analyzed?
    end

    def purge_dependent_blob_later
      blob&.purge_later if dependent == :purge_later
    end


    def dependent
      record.attachment_reflections[name]&.options[:dependent]
    end
end

ActiveSupport.run_load_hooks :active_storage_attachment, ActiveStorage::Attachment
