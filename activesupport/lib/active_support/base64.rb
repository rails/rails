begin
  require 'base64'
rescue LoadError
  # The Base64 module isn't available in ealier versions of Ruby 1.9.
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

unless Base64.respond_to?(:strict_encode64)
  # Included in Ruby 1.9
  def Base64.strict_encode64(value)
    encode64(value).gsub(/\n/, '')
  end
end

module ActiveSupport
  Base64 = ActiveSupport::Deprecation::DeprecatedConstantProxy.new('ActiveSupport::Base64', '::Base64')
  
  # *DEPRECATED*: Use +Base64.strict_encode64+ instead.
  #
  # Encodes the value as base64 without the newline breaks. This makes the base64 encoding readily usable as URL parameters
  # or memcache keys without further processing.
  #
  #  ActiveSupport::Base64.encode64s("Original unencoded string")
  #  # => "T3JpZ2luYWwgdW5lbmNvZGVkIHN0cmluZw=="
  def Base64.encode64s(value)
    ActiveSupport::Deprecation.warn "encode64s " \
      "is deprecated. Use Base64.strict_encode64 instead", caller
    encode64(value).gsub(/\n/, '')
  end
end
