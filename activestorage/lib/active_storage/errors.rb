# frozen_string_literal: true

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

  if defined?(Rails)
    require "active_support/actionable_error"
    require "rails/command"

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
        [Blob, Attachment].any? { |model| error.message.match?(model.table_name) }
      end

      action "Install now" do
        Rails::Command.invoke("active_storage:install")
        Rails::Command.invoke("db:migrate")
      end
    end
  end
end
