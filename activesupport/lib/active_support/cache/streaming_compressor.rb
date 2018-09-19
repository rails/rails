# frozen_string_literal: true

require "zlib"
require "concurrent/executor/cached_thread_pool"
require "active_support/core_ext/numeric/bytes"

module ActiveSupport
  module Cache
    # Serializes object and compresses serialized representation in streaming way.
    # This avoids storing whole copy of serialized intermediate representation,
    # like this happens in `Zlib.deflate(Marshal.dump(value))`.
    module StreamingCompressor
      DEFLATE_BUFFER_SIZE = 16.kilobytes.to_i
      INFLATE_CHUNK_SIZE = 4.kilobyte.to_i

      extend self

      # Dumps value into string. Returns nil if `:compress_threshold` option
      # is set and serialized value is less than given value.
      def dump(value, **options)
        io = StringIO.new
        raw_bytes = dump_to_io(value, io, **options)
        return unless raw_bytes
        io.rewind
        result = io.read
        result if result.bytesize < raw_bytes
      end

      # Same as dump but streams compressed data. Returns nil and don't stream
      # anything if `:compress_threshold` option is set
      # and serialized value is less than given value.
      def dump_to_io(value, to_io, compress_threshold: nil)
        rio, wio = binary_pipe
        within_safe_thread do
          begin
            Marshal.dump(value, wio)
          ensure
            wio.close
          end
        end
        if compress_threshold
          chunk = rio.read([DEFLATE_BUFFER_SIZE, compress_threshold].max)
          return if chunk.bytesize < compress_threshold
        end
        deflate(rio, to_io, initial_chunk: chunk)
      end

      def load(value)
        rio, wio = binary_pipe
        within_safe_thread do
          begin
            inflate(value, wio)
          ensure
            wio.close
          end
        end
        Marshal.load(rio)
      end

      # Compresses data from IO stream to another one.
      # Returns number of processed bytes.
      def deflate(from_io, to_io, initial_chunk: nil)
        processed_bytes = initial_chunk&.bytesize || 0
        zlib = Zlib::Deflate.new
        to_io << zlib.deflate(initial_chunk) if initial_chunk
        until from_io.eof?
          chunk = from_io.read(DEFLATE_BUFFER_SIZE)
          to_io << zlib.deflate(chunk)
          processed_bytes += chunk.bytesize
        end
        to_io << zlib.finish
        processed_bytes
      ensure
        zlib.close
      end

      def inflate(value, to_io)
        zlib = Zlib::Inflate.new
        from_io = StringIO.new(value)
        to_io << zlib.inflate(from_io.read(INFLATE_CHUNK_SIZE)) until from_io.eof?
      ensure
        zlib.close
      end

      private

        def binary_pipe
          rio, wio = IO.pipe(binmode: true)
          wio.set_encoding(Encoding::BINARY)
          [rio, wio]
        end

        def thread_pool
          @thread_pool ||= Concurrent::CachedThreadPool.new
        end

        # Runs task within thread and forwards all exceptions to parent thread.
        def within_safe_thread
          parent_thread = Thread.current
          thread_pool.post do
            begin
              yield
            rescue Exception => e
              parent_thread.raise(e)
            end
          end
        end
    end
  end
end
