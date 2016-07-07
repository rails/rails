require 'digest'

module ActiveSupport
  module SecurityUtils
    # Constant time string comparison.
    #
    # The values compared should be of fixed length, such as strings
    # that have already been processed by HMAC. This should not be used
    # on variable length plaintext strings because it could leak length info
    # via timing attacks.
    def secure_compare(a, b)
      return false unless a.bytesize == b.bytesize

      l = a.unpack "C#{a.bytesize}"

      res = 0
      b.each_byte { |byte| res |= byte ^ l.shift }
      res == 0
    end
    module_function :secure_compare

    def variable_size_secure_compare(a, b) # :nodoc:
      secure_compare(::Digest::SHA256.hexdigest(a), ::Digest::SHA256.hexdigest(b))
    end
    module_function :variable_size_secure_compare
  end
end
