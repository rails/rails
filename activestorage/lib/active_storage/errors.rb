# frozen_string_literal: true

module ActiveStorage
  # Generic Active Storage exception class.
  class ActiveStorageError < StandardError; end
  
  class InvariableError < ActiveStorageError; end
  class UnpreviewableError < ActiveStorageError; end
  class UnrepresentableError < ActiveStorageError; end

  # Raised when uploaded or downloaded data does not match a precomputed checksum.
  # Indicates that a network error or a software bug caused data corruption.
  class IntegrityError < ActiveStorageError; end
end
