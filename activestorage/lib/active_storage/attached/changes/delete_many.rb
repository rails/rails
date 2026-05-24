# frozen_string_literal: true

module ActiveStorage
  class Attached::Changes::DeleteMany # :nodoc:
    include ActiveStorage::Attached::Changes::OwnerDispatch

    attr_reader :name
    attr_accessor :record

    def initialize(name, record)
      @name, @record = name, record
    end

    def attachables
      []
    end

    def attachments
      ar_owner? ? ::ActiveStorage::Attachment.none : []
    end

    def blobs
      ar_owner? ? ::ActiveStorage::Blob.none : []
    end

    def analyze
      # Nothing to analyze when deleting
    end

    def save
      if ar_owner?
        record.public_send("#{name}_attachments=", [])
      else
        reset_deferred_purges

        begin
          attachment_class.transaction do
            attachment_class
              .where(record_type: polymorphic_owner_type, record_id: record.id, name: name)
              .each { |attachment| collect_deferred_purge(attachment) }
          end
        rescue StandardError
          reset_deferred_purges
          raise
        end

        record.public_send("#{name}_attachments").reset if record.public_send("#{name}_attachments").respond_to?(:reset)
        record.public_send("#{name}_blobs").reset if record.public_send("#{name}_blobs").respond_to?(:reset)
      end
    end
  end
end
