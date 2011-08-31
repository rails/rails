require 'zlib'
require 'stringio'
require 'active_support/core_ext/string/encoding'

module ActiveSupport
  # A convenient wrapper for the zlib standard library that allows compression/decompression of strings with gzip.
  module Gzip
    class Stream < StringIO
      def initialize(*)
        super
        set_encoding "BINARY" if "".encoding_aware?
      end
      def close; rewind; end
    end

    # Decompresses a gzipped string.
    def self.decompress(source)
      Zlib::GzipReader.new(StringIO.new(source)).read
    end

    # Compresses a string using gzip.
    def self.compress(source)
      output = Stream.new
      gz = Zlib::GzipWriter.new(output)
      gz.write(source)
      gz.close
      output.string
    end
  end
end
