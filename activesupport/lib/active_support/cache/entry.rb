# This class is used to represent cache entries. Cache entries have a value and an optional
# expiration time. The expiration time is used to support the :race_condition_ttl option
# on the cache.
#
# Since cache entries in most instances will be serialized, the internals of this class are highly optimized
# using short instance variable names that are lazily defined.
module ActiveSupport
  module Cache
    class Entry # :nodoc:
      DEFAULT_COMPRESS_LIMIT = 16.kilobytes

      MAX_OVERHEAD = 129
      MIN_OVERHEAD = 85

      # Max overhead bytes for a Marshal-serialized string.
      MAX_STRING_OVERHEAD = 15

      def self.new(*args)
        entry = ASCE_5.allocate
        entry.send(:initialize, *args)
        entry
      end

      # Create a new cache entry for the specified value. Options supported are
      # +:compress+, +:compress_threshold+, and +:expires_in+.
      def initialize(value, options = {})
        if should_compress?(value, options)
          @value = compress(value)
          @compressed = true
        else
          @value = value
        end

        @created_at = Time.now.to_f
        @expires_in = options[:expires_in]
        @expires_in = @expires_in.to_f if @expires_in
      end

      def value
        compressed? ? uncompress(@value) : @value
      end

      # Check if the entry is expired. The +expires_in+ parameter can override
      # the value set when the entry was created.
      def expired?
        @expires_in && @created_at + @expires_in <= Time.now.to_f
      end

      def expires_at
        @expires_in ? @created_at + @expires_in : nil
      end

      def expires_at=(value)
        if value
          @expires_in = value.to_f - @created_at
        else
          @expires_in = nil
        end
      end

      # Returns the size of the cached value. This could be less than
      # <tt>value.size</tt> if the data is compressed.
      def size
        if defined?(@s)
          @s
        else
          case value
            when NilClass
              0
            when String
              @value.bytesize + MAX_STRING_OVERHEAD
            else
              @s = Marshal.dump(@value).bytesize
          end
        end
      end

      # Duplicate the value in a class. This is used by cache implementations that don't natively
      # serialize entries to protect against accidental cache modifications.
      def dup_value!
        if @value && !compressed? && !(@value.is_a?(Numeric) || @value == true || @value == false)
          if @value.is_a?(String)
            @value = @value.dup
          else
            @value = Marshal.load(Marshal.dump(@value))
          end
        end
      end

      private
      def should_compress?(value, options)
        if value && options[:compress]
          compress_threshold = options[:compress_threshold] || DEFAULT_COMPRESS_LIMIT
          serialized_value_size = (value.is_a?(String) ? value : Marshal.dump(value)).bytesize

          return true if serialized_value_size >= compress_threshold
        end

        false
      end

      def compressed?
        defined?(@compressed) ? @compressed : false
      end

      def compress(value)
        Zlib::Deflate.deflate(Marshal.dump(value))
      end

      def uncompress(value)
        Marshal.load(Zlib::Inflate.inflate(value))
      end
    end
  end
end
