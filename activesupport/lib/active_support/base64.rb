require 'active_support/deprecation'

begin
  require 'base64'
rescue LoadError
  # The Base64 module isn't available in earlier versions of Ruby 1.9.
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
  module Base64
    def self.encode64(value)
      ActiveSupport::Deprecation.warn "ActiveSupport::Base64.encode64 " \
        "is deprecated. Use Base64.encode64 instead", caller
      ::Base64.encode64(value)
    end

    def self.decode64(value)
      ActiveSupport::Deprecation.warn "ActiveSupport::Base64.decode64 " \
        "is deprecated. Use Base64.decode64 instead", caller
      ::Base64.decode64(value)
    end

    def self.encode64s(value)
      ActiveSupport::Deprecation.warn "ActiveSupport::Base64.encode64s " \
        "is deprecated. Use Base64.strict_encode64 instead", caller
      ::Base64.strict_encode64(value)
    end
  end
end
