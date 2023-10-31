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

    def attachment
      @attachment ||= find_or_build_attachment
    end

    def blob
      @blob ||= find_or_build_blob
    end

    def upload
      case attachable
      when ActionDispatch::Http::UploadedFile
        blob.upload_without_unfurling(attachable.open)
      when Rack::Test::UploadedFile
        blob.upload_without_unfurling(
          attachable.respond_to?(:open) ? attachable.open : attachable
        )
      when Hash
        blob.upload_without_unfurling(attachable.fetch(:io))
      when File
        blob.upload_without_unfurling(attachable)
      when Pathname
        blob.upload_without_unfurling(attachable.open)
      when ActiveStorage::Blob
      when String
      else
        raise(
          ArgumentError,
          "Could not upload: expected attachable, " \
            "got #{attachable.inspect}"
        )
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
        ActiveStorage::Attachment.new(record: record, name: name, blob: blob)
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
          ActiveStorage::Blob.validate_service_configuration(service_name, record.class, name)
        end
        service_name
      end
  end
end
