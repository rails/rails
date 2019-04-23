# frozen_string_literal: true

require "active_support/actionable_error"
require "rails/command"

module ActiveStorage
  # Generic base class for all Active Storage exceptions.
  class Error < StandardError; end

  # Raised when ActiveStorage::Blob#variant is called on a blob that isn't variable.
  # Use ActiveStorage::Blob#variable? to determine whether a blob is variable.
  class InvariableError < Error; end

  # Raised when ActiveStorage::Blob#preview is called on a blob that isn't previewable.
  # Use ActiveStorage::Blob#previewable? to determine whether a blob is previewable.
  class UnpreviewableError < Error; end

  # Raised when ActiveStorage::Blob#representation is called on a blob that isn't representable.
  # Use ActiveStorage::Blob#representable? to determine whether a blob is representable.
  class UnrepresentableError < Error; end

  # Raised when uploaded or downloaded data does not match a precomputed checksum.
  # Indicates that a network error or a software bug caused data corruption.
  class IntegrityError < Error; end

  # Raised when ActiveStorage::Blob#download is called on a blob where the
  # backing file is no longer present in its service.
  class FileNotFoundError < Error; end

  # Raised when we detect that Active Storage has not been initialized.
  class SetupError < Error
    include ActiveSupport::ActionableError

    def initialize(message = nil)
      return super if message

      super("Active Storage uses two tables in your application’s database named " \
            "active_storage_blobs and active_storage_attachments. To generate them " \
            "run the following command:\n\n        rails active_storage:install")
    end

    action "Run active_storage:install" do
      Rails::Command.invoke "active_storage:install"
    end
  end
end
