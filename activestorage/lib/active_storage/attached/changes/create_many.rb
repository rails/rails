# frozen_string_literal: true

module ActiveStorage
  class Attached::Changes::CreateMany # :nodoc:
    include ActiveStorage::Attached::Changes::OwnerDispatch

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
      if ar_owner?
        assign_associated_attachments
        reset_associated_blobs
      else
        reset_deferred_purges
        subchange_entries = []

        begin
          attachment_class.transaction do
            subchanges.each do |subchange|
              subchange_entries << {
                subchange: subchange,
                attachment_was_new: subchange.attachment.new_record?,
                blob_was_new: !subchange.blob.persisted?
              }
              subchange.save
            end

            new_blob_ids = subchanges.map(&:blob).filter_map(&:id)

            attachment_class
              .where(record_type: polymorphic_owner_type, record_id: record.id, name: name)
              .where.not(blob_id: new_blob_ids)
              .each { |attachment| collect_deferred_purge(attachment) }
          end
        rescue StandardError
          cleanup_new_records_after_failed_save(subchange_entries)
          reset_deferred_purges
          raise
        end

        record.public_send("#{name}_attachments").reset if record.public_send("#{name}_attachments").respond_to?(:reset)
        record.public_send("#{name}_blobs").reset if record.public_send("#{name}_blobs").respond_to?(:reset)
      end
    end

    private
      def subchanges
        @subchanges ||= attachables.collect { |attachable| build_subchange_from(attachable) }
      end

      def build_subchange_from(attachable)
        ActiveStorage::Attached::Changes::CreateOneOfMany.new(name, record, attachable)
      end

      def subchanges_without_blobs
        subchanges.reject { |subchange| subchange.attachable.is_a?(blob_class) }
      end

      def cleanup_new_records_after_failed_save(entries)
        entries.each do |entry|
          next unless entry[:attachment_was_new]

          cleanup_record_after_failed_many_save(entry[:subchange].attachment, "attachment")
        end

        entries.each do |entry|
          next unless entry[:blob_was_new]

          cleanup_record_after_failed_many_save(entry[:subchange].blob, "blob")
        end
      end

      def cleanup_record_after_failed_many_save(record, label)
        record.destroy if record.persisted? && record.respond_to?(:destroy)
      rescue StandardError => error
        # Don't shadow the original attachment save failure.
        ActiveStorage.logger&.warn(
          "[ActiveStorage] Failed to clean up #{label} after attachments save failed: #{error.class}: #{error.message}"
        )
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
