# frozen_string_literal: true

require "action_dispatch"
require "action_dispatch/http/upload"

module ActiveStorage
  class Attached::Changes::CreateOne # :nodoc:
    attr_reader :name, :record, :attachable

    def initialize(name, record, attachable)
      @name, @record, @attachable = name, record, attachable
      blob.identify_without_saving
    end

    def analyze
      return unless has_immediate_variants?
      with_local_io { blob.analyze_without_saving unless blob.analyzed? }
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
      record.public_send("#{name}_attachment=", attachment)
      record.public_send("#{name}_blob=", blob)
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
        ActiveStorage::Attachment.new(record: record, name: name, blob: blob).tap do |attachment|
          attachment.pending_upload = pending_upload?
        end
      end

      def pending_upload?
        case attachable
        when ActiveStorage::Blob, String then false
        else true
        end
      end

      def find_or_build_blob
        case attachable
        when ActiveStorage::Blob
          attachable
        when ActionDispatch::Http::UploadedFile
          ActiveStorage::Blob.build_after_unfurling(
            io: attachable.open,
            filename: attachable.original_filename,
            content_type: attachable.content_type,
            record: record,
            service_name: attachment_service_name
          )
        when Rack::Test::UploadedFile
          ActiveStorage::Blob.build_after_unfurling(
            io: attachable.respond_to?(:open) ? attachable.open : attachable,
            filename: attachable.original_filename,
            content_type: attachable.content_type,
            record: record,
            service_name: attachment_service_name
          )
        when Hash
          ActiveStorage::Blob.build_after_unfurling(
            **attachable.reverse_merge(
              record: record,
              service_name: attachment_service_name
            ).symbolize_keys
          )
        when String
          ActiveStorage::Blob.find_signed!(attachable, record: record)
        when File
          ActiveStorage::Blob.build_after_unfurling(
            io: attachable,
            filename: File.basename(attachable),
            record: record,
            service_name: attachment_service_name
          )
        when Pathname
          ActiveStorage::Blob.build_after_unfurling(
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

      def has_immediate_variants?
        named_variants.any? { |_name, named_variant| named_variant.process(record) == :immediately }
      end

      def named_variants
        record.attachment_reflections[name]&.named_variants || {}
      end

      def open_attachable_io
        case attachable
        when ActionDispatch::Http::UploadedFile
          attachable.open
        when Rack::Test::UploadedFile
          attachable.respond_to?(:open) ? attachable.open : attachable
        when Hash
          attachable.fetch(:io)
        when File
          attachable
        when Pathname
          attachable.open
        when ActiveStorage::Blob, String
          nil
        else
          raise ArgumentError, "Could not upload: expected attachable, got #{attachable.inspect}"
        end
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
