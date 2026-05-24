# frozen_string_literal: true

require "action_dispatch"
require "action_dispatch/http/upload"

module ActiveStorage
  class Attached::Changes::CreateOne # :nodoc:
    include ActiveStorage::Attached::Changes::OwnerDispatch

    attr_reader :name, :attachable
    attr_accessor :record

    def initialize(name, record, attachable)
      @name, @record, @attachable = name, record, attachable
      @analyzed_immediately = false
      blob.identify_without_saving
    end

    def analyze
      return unless analyze_immediately?

      with_local_io do
        unless blob.analyzed?
          blob.analyze_without_saving
          @analyzed_immediately = true
        end
      end
    end

    def attachment
      @attachment ||= find_or_build_attachment
    end

    def blob
      @blob ||= find_or_build_blob
    end

    def upload
      if io = open_attachable_io
        attachment.uploaded(io: io)
      end
    end

    def save
      if ar_owner?
        record.public_send("#{name}_attachment=", attachment)
        record.public_send("#{name}_blob=", blob)
      else
        reset_deferred_purges

        # Capture before the transaction so the rescue can clean up the right
        # records: the rescue must wrap the whole +transaction+ (not just its
        # body) because a backend that defers writes to commit can fail *after*
        # the block returns, and that failure still has to roll back the new
        # blob/attachment.
        blob_was_new = !blob.persisted?
        attachment_was_new = attachment.new_record?

        begin
          attachment_class.transaction do
            blob.save! if blob_was_new
            blob.save! if @analyzed_immediately && !blob_was_new

            attachment.assign_attributes(
              record_type: polymorphic_owner_type,
              record_id: record.id,
              name: name,
              blob_id: blob.id
            )
            attachment.save!

            unless many?
              attachment_class
                .where(record_type: polymorphic_owner_type, record_id: record.id, name: name)
                .where.not(blob_id: blob.id)
                .each { |attachment| collect_deferred_purge(attachment) }
            end
          end
        rescue StandardError
          cleanup_new_records_after_failed_save(attachment_was_new, blob_was_new)
          reset_deferred_purges
          raise
        end

        unless many?
          record.public_send("#{name}_attachment=", attachment)
          record.public_send("#{name}_blob=", blob)
        end
      end
    end

    private
      def find_or_build_attachment
        find_attachment || build_attachment
      end

      def find_attachment
        if record.public_send("#{name}_blob") == blob
          record.public_send("#{name}_attachment")
        end
      end

      def build_attachment
        attachment_class.new(record: record, name: name, blob: blob).tap do |attachment|
          attachment.pending_upload = pending_upload?
        end
      end

      def cleanup_new_records_after_failed_save(attachment_was_new, blob_was_new)
        attachment.destroy if attachment_was_new && attachment.persisted? && attachment.respond_to?(:destroy)
        blob.destroy if blob_was_new && blob.persisted? && blob.respond_to?(:destroy)
      rescue StandardError => error
        # Don't shadow the original attachment save failure.
        ActiveStorage.logger&.warn(
          "[ActiveStorage] Failed to clean up records after attachment save failed: #{error.class}: #{error.message}"
        )
      end

      def pending_upload?
        case attachable
        when blob_class, String then false
        else true
        end
      end

      def find_or_build_blob
        case attachable
        when blob_class
          attachable
        when ActionDispatch::Http::UploadedFile
          blob_class.build_after_unfurling(
            io: attachable.open,
            filename: attachable.original_filename,
            content_type: attachable.content_type,
            record: record,
            service_name: attachment_service_name
          )
        when Rack::Test::UploadedFile
          blob_class.build_after_unfurling(
            io: attachable.respond_to?(:open) ? attachable.open : attachable,
            filename: attachable.original_filename,
            content_type: attachable.content_type,
            record: record,
            service_name: attachment_service_name
          )
        when Hash
          blob_class.build_after_unfurling(
            **attachable.reverse_merge(
              record: record,
              service_name: attachment_service_name
            ).symbolize_keys
          )
        when String
          blob_class.find_signed!(attachable, record: record)
        when File, Tempfile
          blob_class.build_after_unfurling(
            io: attachable,
            filename: File.basename(attachable),
            record: record,
            service_name: attachment_service_name
          )
        when Pathname
          blob_class.build_after_unfurling(
            io: attachable.open,
            filename: File.basename(attachable),
            record: record,
            service_name: attachment_service_name
          )
        else
          raise(
            ArgumentError,
            "Could not find or build blob: expected attachable, " \
              "got #{attachable.inspect}"
          )
        end
      end

      def attachment_service_name
        service_name = record.attachment_reflections[name].options[:service_name]
        if service_name.is_a?(Proc)
          service_name = service_name.call(record)
          Attached::Model.validate_service_configuration(service_name, record.class, name)
        end
        service_name
      end

      def analyze_immediately?
        case analyze_option
        when :immediately then true
        when :later, :lazily then false
        when nil then has_immediate_variants? || ActiveStorage.analyze == :immediately
        else
          raise ArgumentError, "Unknown analyze option: #{analyze_option.inspect}. Valid options are :immediately, :later, :lazily."
        end
      end

      def analyze_option
        reflection&.options&.fetch(:analyze, nil)
      end

      def reflection
        record.attachment_reflections[name]
      end

      def has_immediate_variants?
        named_variants.any? { |_name, named_variant| named_variant.process(record) == :immediately }
      end

      def named_variants
        reflection&.named_variants || {}
      end

      def open_attachable_io
        case attachable
        when ActionDispatch::Http::UploadedFile
          attachable.open
        when Rack::Test::UploadedFile
          attachable.respond_to?(:open) ? attachable.open : attachable
        when Hash
          attachable.fetch(:io)
        when File, Tempfile
          attachable
        when Pathname
          attachable.open
        when blob_class, String
          nil
        else
          raise ArgumentError, "Could not upload: expected attachable, got #{attachable.inspect}"
        end
      end

      def many?
        false
      end

      def with_local_io
        io = open_attachable_io if pending_upload? && !blob.local_io

        if io
          blob.local_io = io
          io.rewind if io.respond_to?(:rewind)
        end

        yield if io || blob.local_io
      ensure
        blob.local_io = nil if io
      end
  end
end
