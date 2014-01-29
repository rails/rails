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

    # Start of RingRevenue patch
    # from https://rails.lighthouseapp.com/projects/8994/tickets/2078-implement-base64url-encoding-rfc-4648
    BASE64_PUNCTUATION = '+/'
    BASE64_URL_PUNCTUATION = '-_'

    # Encodes passed data using "base64url" (as defined by RFC4648). This makes the base64 encoding readily usable as URL parameters
    # not requiring percent-encoding. No padding '=' or newline breaks are used, and the '+' and '/' characters of standard Base64
    # encoding are respectively replaced by '-' and '_'.
    # ==== Examples
    # ActiveSupport::Base64.encode64("\377\377\276a") # => "//++YQ==\n"
    # ActiveSupport::Base64.encode64_url("\377\377\276a") # => "__--YQ"
    # ActiveSupport::Base64.decode64_url("__--YQ") # => "\377\377\276a"
    def self.encode64_url(data)
      ::Base64.encode64(data).tr(BASE64_PUNCTUATION, BASE64_URL_PUNCTUATION).gsub(/=*\n/, '')
    end

    # Decodes a "base64url" encoded string to its original representation.
    # See <tt>Encoding#encode64_url</tt> for more information.
    def self.decode64_url(str)
      # add '=' padding
      str = case str.length % 4
        when 2 then str + '=='
        when 3 then str + '='
        else
          str
      end

      ::Base64.decode64(str.tr(BASE64_URL_PUNCTUATION, BASE64_PUNCTUATION))
    end
    # End of RingRevenue patch
  end
end
