# frozen_string_literal: true

module ActiveStorage
  class Attached::Changes::CreateMany #:nodoc:
    attr_reader :name, :record, :attachables, :key

    def initialize(name, record, attachables, key)
      @name, @record, @attachables, @key = name, record, Array(attachables), key
      blobs.each(&:identify_without_saving)
      attachments
    end

    def attachments
      @attachments ||= subchanges.collect(&:attachment)
    end

    def blobs
      @blobs ||= subchanges.collect(&:blob)
    end

    def upload
      subchanges.each(&:upload)
    end

    def save
      assign_associated_attachments
      reset_associated_blobs

      unless key.blank?
        blobs.each |blob| do
          blob.move_to!(
            ActiveStorage::Blob.generate_unique_interpolated_secure_key(key: key, record: record, blob: blob)
          )
        end
      end
    end

    private
      def subchanges
        @subchanges ||= attachables.collect { |attachable| build_subchange_from(attachable) }
      end

      def build_subchange_from(attachable)
        ActiveStorage::Attached::Changes::CreateOneOfMany.new(name, record, attachable, key)
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
