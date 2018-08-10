# frozen_string_literal: true

module ActiveStorage
  # Generic base class for all Active Storage exceptions.
  class Error < StandardError; end

  class InvariableError < Error; end
  class UnpreviewableError < Error; end
  class UnrepresentableError < Error; end

  # Raised when uploaded or downloaded data does not match a precomputed checksum.
  # Indicates that a network error or a software bug caused data corruption.
  class IntegrityError < Error; end
end
