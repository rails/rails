# frozen_string_literal: true

require "active_support/core_ext/module/delegation"

# Attachments associate records with blobs. Usually that's a one record-many blobs relationship,
# but it is possible to associate many different records with the same blob. If you're doing that,
# you'll want to declare with <tt>has_one/many_attached :thingy, dependent: false</tt>, so that destroying
# any one record won't destroy the blob as well. (Then you'll need to do your own garbage collecting, though).
class ActiveStorage::Attachment < ActiveRecord::Base
  self.table_name = "active_storage_attachments"

  belongs_to :record, polymorphic: true, touch: true
  belongs_to :blob, class_name: "ActiveStorage::Blob"

  delegate_missing_to :blob

  after_create_commit :analyze_blob_later, :identify_blob

  # Synchronously purges the blob (deletes it from the configured service) and destroys the attachment.
  def purge
    destroy
    blob.purge
  end

  # Destroys the attachment and asynchronously purges the blob (deletes it from the configured service).
  def purge_later
    destroy
    blob.purge_later
  end

  private
    def identify_blob
      blob.identify
    end

    def analyze_blob_later
      blob.analyze_later unless blob.analyzed?
    end
end
