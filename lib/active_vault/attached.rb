require "active_vault/blob"
require "active_vault/attachment"

require "action_dispatch/http/upload"
require "active_support/core_ext/module/delegation"

class ActiveVault::Attached
  attr_reader :name, :record

  def initialize(name, record)
    @name, @record = name, record
  end

  private
    def create_blob_from(attachable)
      case attachable
      when ActiveVault::Blob
        attachable
      when ActionDispatch::Http::UploadedFile
        ActiveVault::Blob.create_after_upload! \
          io: attachable.open,
          filename: attachable.original_filename,
          content_type: attachable.content_type
      when Hash
        ActiveVault::Blob.create_after_upload!(attachable)
      else
        nil
      end
    end
end

require "active_vault/attached/one"
require "active_vault/attached/many"
require "active_vault/attached/macros"
