module Sprockets
  class NullCompressor
    def compress(content)
      content
    end
  end

  class LazyCompressor
    def initialize(&block)
      @block = block
    end

    def compressor
      @compressor ||= @block.call || NullCompressor.new
    end

    def compress(content)
      compressor.compress(content)
    end
  end
end