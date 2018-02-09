# frozen_string_literal: true

require "action_dispatch"
require "action_dispatch/http/upload"
require "active_support/core_ext/module/delegation"

module ActiveStorage
  # Abstract base class for the concrete ActiveStorage::Attached::One and ActiveStorage::Attached::Many
  # classes that both provide proxy access to the blob association for a record.
  class Attached
    attr_reader :name, :record, :dependent

    def initialize(name, record, dependent:)
      @name, @record, @dependent = name, record, dependent
    end

    private
      def create_blob_from(attachable)
        case attachable
        when ActiveStorage::Blob
          attachable
        when ActionDispatch::Http::UploadedFile, Rack::Test::UploadedFile
          ActiveStorage::Blob.create_after_upload! \
            io: attachable.open,
            filename: attachable.original_filename,
            content_type: attachable.content_type
        when URI::HTTP, URI::HTTPS
          io = attachable.open
          ActiveStorage::Blob.create_after_upload! \
            io: io,
            filename: File.basename(attachable.path),
            content_type: io.content_type
        when Hash
          ActiveStorage::Blob.create_after_upload!(attachable)
        when String
          uri = URI.parse(attachable)
          if uri.respond_to?(:open)
            create_blob_from(uri)
          else
            ActiveStorage::Blob.find_signed(attachable)
          end
        else
          nil
        end
      end
  end
end

require "active_storage/attached/one"
require "active_storage/attached/many"
require "active_storage/attached/macros"
