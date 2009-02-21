if RUBY_VERSION == "1.9.1" && defined?(RUBY_PATCHLEVEL) && RUBY_PATCHLEVEL == 0
  require 'uri'
  URI::Parser.class_eval do
    remove_method :unescape
    def unescape(str, escaped = @regexp[:ESCAPED])
      enc = (str.encoding == Encoding::US_ASCII) ? Encoding::UTF_8 : str.encoding
      str.gsub(escaped) { [$&[1, 2].hex].pack('C') }.force_encoding(enc)
    end
  end
end
