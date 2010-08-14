begin
  require 'base64'
rescue LoadError
end

module ActiveSupport
  if defined? ::Base64
    Base64 = ::Base64
  else
    # Base64 provides utility methods for encoding and de-coding binary data
    # using a base 64 representation. A base 64 representation of binary data
    # consists entirely of printable US-ASCII characters. The Base64 module
    # is included in Ruby 1.8, but has been removed in Ruby 1.9.
    module Base64
      # Encodes a string to its base 64 representation. Each 60 characters of
      # output is separated by a newline character.
      #
      #  ActiveSupport::Base64.encode64("Original unencoded string")
      #  # => "T3JpZ2luYWwgdW5lbmNvZGVkIHN0cmluZw==\n"
      def self.encode64(data)
        [data].pack("m")
      end

      # Decodes a base 64 encoded string to its original representation.
      #
      #  ActiveSupport::Base64.decode64("T3JpZ2luYWwgdW5lbmNvZGVkIHN0cmluZw==")
      #  # => "Original unencoded string"
      def self.decode64(data)
        data.unpack("m").first
      end
    end
  end

  # Encodes the value as base64 without the newline breaks. This makes the base64 encoding readily usable as URL parameters
  # or memcache keys without further processing.
  #
  #  ActiveSupport::Base64.encode64s("Original unencoded string")
  #  # => "T3JpZ2luYWwgdW5lbmNvZGVkIHN0cmluZw=="
  def Base64.encode64s(value)
    encode64(value).gsub(/\n/, '')
  end
end
