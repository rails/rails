# frozen_string_literal: true

module ActiveStorage
  class InvariableError < StandardError; end
  class UnpreviewableError < StandardError; end
  class UnrepresentableError < StandardError; end

  # Raised when uploaded or downloaded data does not match a precomputed checksum.
  # Indicates that a network error or a software bug caused data corruption.
  class IntegrityError < StandardError; end
end
