require 'zlib'
require 'stringio'

module ActiveSupport
  module Gzip
    class Stream < StringIO
      def close; rewind; end
    end

    def self.decompress(source)
      Zlib::GzipReader.new(StringIO.new(source)).read
    end

    def self.compress(source)
      output = Stream.new
      gz = Zlib::GzipWriter.new(output)
      gz.write(source)
      gz.close
      output.string
    end
  end
end