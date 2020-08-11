# frozen_string_literal: true

require "action_dispatch"
require "action_dispatch/http/upload"

module ActiveStorage
  class Attached::Changes::CreateOne #:nodoc:
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
      when ActionDispatch::Http::UploadedFile, Rack::Test::UploadedFile
        blob.upload_without_unfurling(attachable.open)
      when Hash
        blob.upload_without_unfurling(attachable.fetch(:io))
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
        when ActionDispatch::Http::UploadedFile, Rack::Test::UploadedFile
          ActiveStorage::Blob.build_after_unfurling(
            io: attachable.open,
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
        else
          raise ArgumentError, "Could not find or build blob: expected attachable, got #{attachable.inspect}"
        end
      end

      def attachment_service_name
        record.attachment_reflections[name].options[:service_name]
      end
  end
end
