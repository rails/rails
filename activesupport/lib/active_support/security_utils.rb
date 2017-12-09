# frozen_string_literal: true

require "digest/sha2"

module ActiveSupport
  module SecurityUtils
    # Constant time string comparison, for fixed length strings.
    #
    # The values compared should be of fixed length, such as strings
    # that have already been processed by HMAC. Raises in case of length mismatch.
    def fixed_length_secure_compare(a, b)
      raise ArgumentError, "string length mismatch." unless a.bytesize == b.bytesize

      l = a.unpack "C#{a.bytesize}"

      res = 0
      b.each_byte { |byte| res |= byte ^ l.shift }
      res == 0
    end
    module_function :fixed_length_secure_compare

    # Constant time string comparison, for variable length strings.
    #
    # The values are first processed by SHA256, so that we don't leak length info
    # via timing attacks.
    def secure_compare(a, b)
      fixed_length_secure_compare(::Digest::SHA256.hexdigest(a), ::Digest::SHA256.hexdigest(b)) && a == b
    end
    module_function :secure_compare
  end
end
