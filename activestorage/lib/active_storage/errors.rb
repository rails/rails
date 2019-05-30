# frozen_string_literal: true

require "active_support/actionable_error"

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
  class InstallError < Error
    include ActiveSupport::ActionableError

    def initialize(message = nil)
      super(message || <<~MESSAGE)
        Action Storage does not appear to be installed. Do you want to
        install it now?
      MESSAGE
    end

    trigger on: ActiveRecord::StatementInvalid, if: -> error do
      [Blob, Attachment].any? { |model| error.to_s.match?(model.table_name) }
    end

    action "Install now" do
      system "./bin/rails active_storage:install db:migrate"
    end
  end
end
