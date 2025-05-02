# frozen_string_literal: true

begin
  require "dalli"
rescue LoadError => e
  warn "You don't have dalli installed in your application. Please add it to your Gemfile and run bundle install"
  raise e
end

require "connection_pool"
require "delegate"
require "active_support/core_ext/enumerable"
require "active_support/core_ext/array/extract_options"
require "active_support/core_ext/numeric/time"

module ActiveSupport
  module Cache
    # = Memcached \Cache \Store
    #
    # A cache store implementation which stores data in Memcached:
    # https://memcached.org
    #
    # This is currently the most popular cache store for production websites.
    #
    # Special features:
    # - Clustering and load balancing. One can specify multiple memcached servers,
    #   and +MemCacheStore+ will load balance between all available servers. If a
    #   server goes down, then +MemCacheStore+ will ignore it until it comes back up.
    #
    # +MemCacheStore+ implements the Strategy::LocalCache strategy which
    # implements an in-memory cache inside of a block.
    class MemCacheStore < Store
      # These options represent behavior overridden by this implementation and should
      # not be allowed to get down to the Dalli client
      OVERRIDDEN_OPTIONS = UNIVERSAL_OPTIONS

      # Advertise cache versioning support.
      def self.supports_cache_versioning?
        true
      end

      prepend Strategy::LocalCache

      KEY_MAX_SIZE = 250
      ESCAPE_KEY_CHARS = /[\x00-\x20%\x7F-\xFF]/n

      # Creates a new Dalli::Client instance with specified addresses and options.
      # If no addresses are provided, we give nil to Dalli::Client, so it uses its fallbacks:
      # - ENV["MEMCACHE_SERVERS"] (if defined)
      # - "127.0.0.1:11211"        (otherwise)
      #
      #   ActiveSupport::Cache::MemCacheStore.build_mem_cache
      #     # => #<Dalli::Client:0x007f98a47d2028 @servers=["127.0.0.1:11211"], @options={}, @ring=nil>
      #   ActiveSupport::Cache::MemCacheStore.build_mem_cache('localhost:10290')
      #     # => #<Dalli::Client:0x007f98a47b3a60 @servers=["localhost:10290"], @options={}, @ring=nil>
      def self.build_mem_cache(*addresses) # :nodoc:
        addresses = addresses.flatten
        options = addresses.extract_options!
        addresses = nil if addresses.compact.empty?
        pool_options = retrieve_pool_options(options)

        if pool_options
          ConnectionPool.new(pool_options) { Dalli::Client.new(addresses, options.merge(threadsafe: false)) }
        else
          Dalli::Client.new(addresses, options)
        end
      end

      # Creates a new +MemCacheStore+ object, with the given memcached server
      # addresses. Each address is either a host name, or a host-with-port string
      # in the form of "host_name:port". For example:
      #
      #   ActiveSupport::Cache::MemCacheStore.new("localhost", "server-downstairs.localnetwork:8229")
      #
      # If no addresses are provided, but <tt>ENV['MEMCACHE_SERVERS']</tt> is defined, it will be used instead. Otherwise,
      # +MemCacheStore+ will connect to localhost:11211 (the default memcached port).
      def initialize(*addresses)
        addresses = addresses.flatten
        options = addresses.extract_options!
        if options.key?(:cache_nils)
          options[:skip_nil] = !options.delete(:cache_nils)
        end
        super(options)

        unless [String, Dalli::Client, NilClass].include?(addresses.first.class)
          raise ArgumentError, "First argument must be an empty array, address, or array of addresses."
        end

        @mem_cache_options = options.dup
        # The value "compress: false" prevents duplicate compression within Dalli.
        @mem_cache_options[:compress] = false
        (OVERRIDDEN_OPTIONS - %i(compress)).each { |name| @mem_cache_options.delete(name) }
        @data = self.class.build_mem_cache(*(addresses + [@mem_cache_options]))
      end

      def inspect
        instance = @data || @mem_cache_options
        "#<#{self.class} options=#{options.inspect} mem_cache=#{instance.inspect}>"
      end

      ##
      # :method: write
      # :call-seq: write(name, value, options = nil)
      #
      # Behaves the same as ActiveSupport::Cache::Store#write, but supports
      # additional options specific to memcached.
      #
      # ==== Additional Options
      #
      # * <tt>raw: true</tt> - Sends the value directly to the server as raw
      #   bytes. The value must be a string or number. You can use memcached
      #   direct operations like +increment+ and +decrement+ only on raw values.
      #
      # * <tt>unless_exist: true</tt> - Prevents overwriting an existing cache
      #   entry.

      # Increment a cached integer value using the memcached incr atomic operator.
      # Returns the updated value.
      #
      # If the key is unset or has expired, it will be set to +amount+:
      #
      #   cache.increment("foo") # => 1
      #   cache.increment("bar", 100) # => 100
      #
      # To set a specific value, call #write passing <tt>raw: true</tt>:
      #
      #   cache.write("baz", 5, raw: true)
      #   cache.increment("baz") # => 6
      #
      # Incrementing a non-numeric value, or a value written without
      # <tt>raw: true</tt>, will fail and return +nil+.
      def increment(name, amount = 1, options = nil)
        options = merged_options(options)
        key = normalize_key(name, options)

        instrument(:increment, key, amount: amount) do
          rescue_error_with nil do
            @data.with { |c| c.incr(key, amount, options[:expires_in], amount) }
          end
        end
      end

      # Decrement a cached integer value using the memcached decr atomic operator.
      # Returns the updated value.
      #
      # If the key is unset or has expired, it will be set to 0. Memcached
      # does not support negative counters.
      #
      #   cache.decrement("foo") # => 0
      #
      # To set a specific value, call #write passing <tt>raw: true</tt>:
      #
      #   cache.write("baz", 5, raw: true)
      #   cache.decrement("baz") # => 4
      #
      # Decrementing a non-numeric value, or a value written without
      # <tt>raw: true</tt>, will fail and return +nil+.
      def decrement(name, amount = 1, options = nil)
        options = merged_options(options)
        key = normalize_key(name, options)

        instrument(:decrement, key, amount: amount) do
          rescue_error_with nil do
            @data.with { |c| c.decr(key, amount, options[:expires_in], 0) }
          end
        end
      end

      # Clear the entire cache on all memcached servers. This method should
      # be used with care when shared cache is being used.
      def clear(options = nil)
        rescue_error_with(nil) { @data.with { |c| c.flush_all } }
      end

      # Get the statistics from the memcached servers.
      def stats
        @data.with { |c| c.stats }
      end

      private
        # Read an entry from the cache.
        def read_entry(key, **options)
          deserialize_entry(read_serialized_entry(key, **options), **options)
        end

        def read_serialized_entry(key, **options)
          rescue_error_with(nil) do
            @data.with { |c| c.get(key, options) }
          end
        end

        # Write an entry to the cache.
        def write_entry(key, entry, **options)
          write_serialized_entry(key, serialize_entry(entry, **options), **options)
        end

        def write_serialized_entry(key, payload, **options)
          method = options[:unless_exist] ? :add : :set
          expires_in = options[:expires_in].to_i
          if options[:race_condition_ttl] && expires_in > 0 && !options[:raw]
            # Set the memcache expire a few minutes in the future to support race condition ttls on read
            expires_in += 5.minutes
          end
          rescue_error_with nil do
            # Don't pass compress option to Dalli since we are already dealing with compression.
            options.delete(:compress)
            @data.with { |c| !!c.send(method, key, payload, expires_in, **options) }
          end
        end

        # Reads multiple entries from the cache implementation.
        def read_multi_entries(names, **options)
          keys_to_names = names.index_by { |name| normalize_key(name, options) }

          rescue_error_with({}) do
            raw_values = @data.with { |c| c.get_multi(keys_to_names.keys) }

            values = {}

            raw_values.each do |key, value|
              entry = deserialize_entry(value, raw: options[:raw])

              unless entry.nil? || entry.expired? || entry.mismatched?(normalize_version(keys_to_names[key], options))
                begin
                  values[keys_to_names[key]] = entry.value
                rescue DeserializationError
                end
              end
            end

            values
          end
        end

        # Delete an entry from the cache.
        def delete_entry(key, **options)
          rescue_error_with(false) { @data.with { |c| c.delete(key) } }
        end

        def serialize_entry(entry, raw: false, **options)
          if raw
            entry.value.to_s
          else
            super(entry, raw: raw, **options)
          end
        end

        # Memcache keys are binaries. So we need to force their encoding to binary
        # before applying the regular expression to ensure we are escaping all
        # characters properly.
        def normalize_key(key, options)
          key = super
          if key
            key = key.dup.force_encoding(Encoding::ASCII_8BIT)
            key = key.gsub(ESCAPE_KEY_CHARS) { |match| "%#{match.getbyte(0).to_s(16).upcase}" }

            if key.size > KEY_MAX_SIZE
              key_separator = ":hash:"
              key_hash = ActiveSupport::Digest.hexdigest(key)
              key_trim_size = KEY_MAX_SIZE - key_separator.size - key_hash.size
              key = "#{key[0, key_trim_size]}#{key_separator}#{key_hash}"
            end
          end
          key
        end

        def deserialize_entry(payload, raw: false, **)
          if payload && raw
            Entry.new(payload)
          else
            super(payload)
          end
        end

        def rescue_error_with(fallback)
          yield
        rescue Dalli::DalliError, ConnectionPool::Error, ConnectionPool::TimeoutError => error
          logger.error("DalliError (#{error}): #{error.message}") if logger
          ActiveSupport.error_reporter&.report(
            error,
            severity: :warning,
            source: "mem_cache_store.active_support",
          )
          fallback
        end
    end
  end
end
