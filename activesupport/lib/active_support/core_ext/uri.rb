# frozen_string_literal: true

require 'uri'

if RUBY_VERSION < '2.6.0'
  require 'active_support/core_ext/module/redefine_method'
  URI::Parser.class_eval do
    silence_redefinition_of_method :unescape
    def unescape(str, escaped = /%[a-fA-F\d]{2}/)
      # TODO: Are we actually sure that ASCII == UTF-8?
      # YK: My initial experiments say yes, but let's be sure please
      enc = str.encoding
      enc = Encoding::UTF_8 if enc == Encoding::US_ASCII
      str.dup.force_encoding(Encoding::ASCII_8BIT).gsub(escaped) { |match| [match[1, 2].hex].pack('C') }.force_encoding(enc)
    end
  end
end

module URI
  class << self
    def parser
      ActiveSupport::Deprecation.warn(<<-MSG.squish)
        URI.parser is deprecated and will be removed in Rails 6.2.
        Use `URI::DEFAULT_PARSER` instead.
      MSG
      URI::DEFAULT_PARSER
    end
  end
end
