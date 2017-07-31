require "active_storage/blob"
require "active_storage/attachment"

require "action_dispatch/http/upload"
require "active_support/core_ext/module/delegation"

# Abstract baseclass for the concrete `ActiveStorage::Attached::One` and `ActiveStorage::Attached::Many`
# classes that both provide proxy access to the blob association for a record.
class ActiveStorage::Attached
  attr_reader :name, :record

  def initialize(name, record)
    @name, @record = name, record
  end

  private
    def create_blob_from(attachable)
      case attachable
      when ActiveStorage::Blob
        attachable
      when ActionDispatch::Http::UploadedFile
        ActiveStorage::Blob.create_after_upload! \
          io: attachable.open,
          filename: attachable.original_filename,
          content_type: attachable.content_type
      when Hash
        ActiveStorage::Blob.create_after_upload!(attachable)
      when String
        ActiveStorage::Blob.find_signed(attachable)
      else
        nil
      end
    end
end

require "active_storage/attached/one"
require "active_storage/attached/many"
require "active_storage/attached/macros"
