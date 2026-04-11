# frozen_string_literal: true

require "active_support/core_ext/securerandom"

module ActiveSupport
  # = Base32
  #
  # Namespace for Base32 encoding schemes.
  #
  # == Available schemes
  #
  # [ActiveSupport::Base32::Crockford]
  #   Crockford's Base32 encoding, designed to be unambiguous for humans. Supports
  #   generation and normalization of human-readable codes.
  #
  #     ActiveSupport::Base32::Crockford.generate(6)          # => "PAK1NG"
  #     ActiveSupport::Base32::Crockford.normalize("OIL-123") # => "011123"
  module Base32
    autoload :Crockford, "active_support/base32/crockford"
  end
end
