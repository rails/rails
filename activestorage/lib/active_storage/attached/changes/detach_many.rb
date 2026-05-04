# frozen_string_literal: true

module ActiveStorage
  class Attached::Changes::DetachMany # :nodoc:
    attr_reader :name, :record, :attachments

    def initialize(name, record, attachments)
      @name, @record, @attachments = name, record, attachments
    end

    def detach
      if attachments.any?
        blob_ids = attachments.filter_map { |a| a.blob_id if a.persisted? }
        attachments.delete_all if attachments.respond_to?(:delete_all)
        ActiveStorage::Blob.where(id: blob_ids).touch_all if blob_ids.any?
        record.attachment_changes.delete(name)
      end
    end
  end
end
