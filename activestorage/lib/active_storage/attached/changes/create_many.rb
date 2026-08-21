# frozen_string_literal: true

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

    private
      def subchanges
        @subchanges ||= begin
          attachments_by_blob = record.public_send("#{name}_attachments").each_with_object({}) do |attachment, index|
            index[attachment.blob_id] ||= attachment
          end
          attachables.collect { |attachable| build_subchange_from(attachable, attachments_by_blob) }
        end
      end

      def build_subchange_from(attachable, attachments_by_blob)
        ActiveStorage::Attached::Changes::CreateOneOfMany.new(name, record, attachable, attachments_by_blob)
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
