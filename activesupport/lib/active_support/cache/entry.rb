# frozen_string_literal: true

require "zlib"

module ActiveSupport
  module Cache
    # This class is used to represent cache entries. Cache entries have a value, an optional
    # expiration time, and an optional version. The expiration time is used to support the :race_condition_ttl option
    # on the cache. The version is used to support the :version option on the cache for rejecting
    # mismatches.
    #
    # Since cache entries in most instances will be serialized, the internals of this class are highly optimized
    # using short instance variable names that are lazily defined.
    class Entry # :nodoc:
      class << self
        def unpack(members)
          new(members[0], expires_at: members[1], version: members[2])
        end
      end

      attr_reader :version

      # Creates a new cache entry for the specified value. Options supported are
      # +:compressed+, +:version+, +:expires_at+ and +:expires_in+.
      def initialize(value, compressed: false, version: nil, expires_in: nil, expires_at: nil, **)
        @value      = value
        @version    = version
        @created_at = 0.0
        @expires_in = expires_at&.to_f || expires_in && (expires_in.to_f + Time.now.to_f)
        @compressed = true if compressed
      end

      def value
        compressed? ? uncompress(@value) : @value
      end

      def mismatched?(version)
        @version && version && @version != version
      end

      # Checks if the entry is expired. The +expires_in+ parameter can override
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
      # <tt>value.bytesize</tt> if the data is compressed.
      def bytesize
        case value
        when NilClass
          0
        when String
          @value.bytesize
        else
          @s ||= Marshal.dump(@value).bytesize
        end
      end

      def compressed? # :nodoc:
        defined?(@compressed)
      end

      def compressed(compress_threshold)
        return self if compressed?

        case @value
        when nil, true, false, Numeric
          uncompressed_size = 0
        when String
          uncompressed_size = @value.bytesize
        else
          serialized = Marshal.dump(@value)
          uncompressed_size = serialized.bytesize
        end

        if uncompressed_size >= compress_threshold
          serialized ||= Marshal.dump(@value)
          compressed = Zlib::Deflate.deflate(serialized)

          if compressed.bytesize < uncompressed_size
            return Entry.new(compressed, compressed: true, expires_at: expires_at, version: version)
          end
        end
        self
      end

      def local?
        false
      end

      # Duplicates the value in a class. This is used by cache implementations that don't natively
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

      def pack
        members = [value, expires_at, version]
        members.pop while !members.empty? && members.last.nil?
        members
      end

      private
        def uncompress(value)
          Marshal.load(Zlib::Inflate.inflate(value))
        end
    end
  end
end
