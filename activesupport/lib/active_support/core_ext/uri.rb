# frozen_string_literal: true

require "uri"
str = "\xE6\x97\xA5\xE6\x9C\xAC\xE8\xAA\x9E" # Ni-ho-nn-go in UTF-8, means Japanese.
parser = URI::Parser.new

unless str == parser.unescape(parser.escape(str))
  require "active_support/core_ext/module/redefine_method"
  URI::Parser.class_eval do
    silence_redefinition_of_method :unescape
    def unescape(str, escaped = /%[a-fA-F\d]{2}/)
      # TODO: Are we actually sure that ASCII == UTF-8?
      # YK: My initial experiments say yes, but let's be sure please
      enc = str.encoding
      enc = Encoding::UTF_8 if enc == Encoding::US_ASCII
      str.dup.force_encoding(Encoding::ASCII_8BIT).gsub(escaped) { |match| [match[1, 2].hex].pack("C") }.force_encoding(enc)
    end
  end
end

module URI
  class << self
    def parser
      @parser ||= URI::Parser.new
    end
  end
end
