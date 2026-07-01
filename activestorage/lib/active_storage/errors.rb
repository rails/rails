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

  # Raised when a Previewer is unable to generate a preview image.
  class PreviewError < Error; end

  # Raised when a storage key resolves to a path outside the service's root
  # directory, indicating a potential path traversal attack.
  class InvalidKeyError < Error; end

  # Raised by non-Active Record backends when a record cannot be found.
  class RecordNotFound < Error; end

  # Raised by non-Active Record backends when a record cannot be saved.
  class RecordNotSaved < Error
    attr_reader :record

    def initialize(message = nil, record = nil)
      super(message)
      @record = record
    end
  end

  # Raised by non-Active Record backends when a record cannot be destroyed.
  class RecordNotDestroyed < Error
    attr_reader :record

    def initialize(message = nil, record = nil)
      super(message)
      @record = record
    end
  end

  # Raised by non-Active Record backends when a record is invalid.
  class RecordInvalid < Error; end

  # Raised by non-Active Record backends for foreign key violations.
  class ForeignKeyViolation < Error; end

  # Raised by non-Active Record backends for deadlock retries.
  class Deadlocked < Error; end

  # Raised for invalid Active Storage backend configuration.
  class ConfigurationError < Error; end

  # Raised when Active Record and custom storage classes are mixed unsafely.
  class HybridConfigurationError < ConfigurationError; end

  # Raised when an unsupported query method is called on a generic collection.
  class QueryNotSupported < Error; end

  # Raised when a non-Active Record owner does not satisfy Active Storage's callback contract.
  class OwnerContractMissing < Error; end

  # Raised when eager loading is requested for a non-Active Record attachment owner.
  class EagerLoadingNotSupported < Error; end
end
