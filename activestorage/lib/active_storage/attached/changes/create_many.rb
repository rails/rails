# frozen_string_literal: true

# :markup: markdown
module ActiveStorage
  class Attached::Changes::CreateMany # :nodoc:
    attr_reader :name, :attachables, :pending_uploads
    attr_accessor :record

    def initialize(name, record, attachables, pending_uploads: [])
      @name, @record, @attachables = name, record, Array(attachables)
      blobs.each(&:identify_without_saving)
      @pending_uploads = Array(pending_uploads) + subchanges_without_blobs
      attachments
    end

    def attachments
      @attachments ||= subchanges.collect(&:attachment)
    end

    def blobs
      @blobs ||= subchanges.collect(&:blob)
    end

    def analyze
      subchanges.each(&:analyze)
    end

    def upload
      pending_uploads.each(&:upload)
    end

    def save
      assign_associated_attachments
      reset_associated_blobs
    end

    def existing_attachment_for(blob)
      existing_attachments_by_blob_id[blob.id]
    end

    private
      def subchanges
        @subchanges ||= attachables.collect { |attachable| build_subchange_from(attachable) }
      end

      def build_subchange_from(attachable)
        ActiveStorage::Attached::Changes::CreateOneOfMany.new(name, record, attachable, self)
      end

      # Built once instead of scanning the attachments for every blob. Keeps the
      # first attachment of each blob, as the scan did.
      def existing_attachments_by_blob_id
        @existing_attachments_by_blob_id ||= record.public_send("#{name}_attachments").each_with_object({}) do |attachment, attachments|
          attachments[attachment.blob_id] ||= attachment
        end
      end

      def subchanges_without_blobs
        subchanges.reject { |subchange| subchange.attachable.is_a?(ActiveStorage::Blob) }
      end

      def assign_associated_attachments
        record.public_send("#{name}_attachments=", persisted_or_new_attachments)
      end

      def reset_associated_blobs
        record.public_send("#{name}_blobs").reset
      end

      def persisted_or_new_attachments
        attachments.select { |attachment| attachment.persisted? || attachment.new_record? }
      end
  end
end
