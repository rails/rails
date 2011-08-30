module Sprockets
  # An asset compressor which does nothing.
  #
  # This compressor simply returns the asset as-is, without any compression
  # whatsoever. It is useful in development mode, when compression isn't
  # needed but using the same asset pipeline as production is desired.
  class NullCompressor #:nodoc:
    def compress(content)
      content
    end
  end

  # An asset compressor which only initializes the underlying compression
  # engine when needed.
  #
  # This postpones the initialization of the compressor until
  # <code>#compress</code> is called the first time.
  class LazyCompressor #:nodoc:
    # Initializes a new LazyCompressor.
    #
    # The block should return a compressor when called, i.e. an object
    # which responds to <code>#compress</code>.
    def initialize(&block)
      @block = block
    end

    def compress(content)
      compressor.compress(content)
    end

    private

    def compressor
      @compressor ||= (@block.call || NullCompressor.new)
    end
  end
end
