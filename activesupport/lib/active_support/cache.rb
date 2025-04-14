# frozen_string_literal: true

require "zlib"
require "active_support/core_ext/array/extract_options"
require "active_support/core_ext/enumerable"
require "active_support/core_ext/module/attribute_accessors"
require "active_support/core_ext/numeric/bytes"
require "active_support/core_ext/object/to_param"
require "active_support/core_ext/object/try"
require "active_support/core_ext/string/inflections"
require_relative "cache/coder"
require_relative "cache/entry"
require_relative "cache/serializer_with_fallback"

module ActiveSupport
  # See ActiveSupport::Cache::Store for documentation.
  module Cache
    autoload :FileStore,        "active_support/cache/file_store"
    autoload :MemoryStore,      "active_support/cache/memory_store"
    autoload :MemCacheStore,    "active_support/cache/mem_cache_store"
    autoload :NullStore,        "active_support/cache/null_store"
    autoload :RedisCacheStore,  "active_support/cache/redis_cache_store"

    # These options mean something to all cache implementations. Individual cache
    # implementations may support additional options.
    UNIVERSAL_OPTIONS = [
      :coder,
      :compress,
      :compress_threshold,
      :compressor,
      :expire_in,
      :expired_in,
      :expires_in,
      :namespace,
      :race_condition_ttl,
      :serializer,
      :skip_nil,
      :raw,
    ]

    # Mapping of canonical option names to aliases that a store will recognize.
    OPTION_ALIASES = {
      expires_in: [:expire_in, :expired_in]
    }.freeze

    DEFAULT_COMPRESS_LIMIT = 1.kilobyte

    # Raised by coders when the cache entry can't be deserialized.
    # This error is treated as a cache miss.
    DeserializationError = Class.new(StandardError)

    module Strategy
      autoload :LocalCache, "active_support/cache/strategy/local_cache"
    end

    @format_version = 7.0

    class << self
      attr_accessor :format_version

      # Creates a new Store object according to the given options.
      #
      # If no arguments are passed to this method, then a new
      # ActiveSupport::Cache::MemoryStore object will be returned.
      #
      # If you pass a Symbol as the first argument, then a corresponding cache
      # store class under the ActiveSupport::Cache namespace will be created.
      # For example:
      #
      #   ActiveSupport::Cache.lookup_store(:memory_store)
      #   # => returns a new ActiveSupport::Cache::MemoryStore object
      #
      #   ActiveSupport::Cache.lookup_store(:mem_cache_store)
      #   # => returns a new ActiveSupport::Cache::MemCacheStore object
      #
      # Any additional arguments will be passed to the corresponding cache store
      # class's constructor:
      #
      #   ActiveSupport::Cache.lookup_store(:file_store, '/tmp/cache')
      #   # => same as: ActiveSupport::Cache::FileStore.new('/tmp/cache')
      #
      # If the first argument is not a Symbol, then it will simply be returned:
      #
      #   ActiveSupport::Cache.lookup_store(MyOwnCacheStore.new)
      #   # => returns MyOwnCacheStore.new
      def lookup_store(store = nil, *parameters)
        case store
        when Symbol
          options = parameters.extract_options!
          retrieve_store_class(store).new(*parameters, **options)
        when Array
          lookup_store(*store)
        when nil
          ActiveSupport::Cache::MemoryStore.new
        else
          store
        end
      end

      # Expands out the +key+ argument into a key that can be used for the
      # cache store. Optionally accepts a namespace, and all keys will be
      # scoped within that namespace.
      #
      # If the +key+ argument provided is an array, or responds to +to_a+, then
      # each of elements in the array will be turned into parameters/keys and
      # concatenated into a single key. For example:
      #
      #   ActiveSupport::Cache.expand_cache_key([:foo, :bar])               # => "foo/bar"
      #   ActiveSupport::Cache.expand_cache_key([:foo, :bar], "namespace")  # => "namespace/foo/bar"
      #
      # The +key+ argument can also respond to +cache_key+ or +to_param+.
      def expand_cache_key(key, namespace = nil)
        expanded_cache_key = namespace ? +"#{namespace}/" : +""

        if prefix = ENV["RAILS_CACHE_ID"] || ENV["RAILS_APP_VERSION"]
          expanded_cache_key << "#{prefix}/"
        end

        expanded_cache_key << retrieve_cache_key(key)
        expanded_cache_key
      end

      private
        def retrieve_cache_key(key)
          case
          when key.respond_to?(:cache_key_with_version) then key.cache_key_with_version
          when key.respond_to?(:cache_key)              then key.cache_key
          when key.is_a?(Array)                         then key.map { |element| retrieve_cache_key(element) }.to_param
          when key.respond_to?(:to_a)                   then retrieve_cache_key(key.to_a)
          else                                               key.to_param
          end.to_s
        end

        # Obtains the specified cache store class, given the name of the +store+.
        # Raises an error when the store class cannot be found.
        def retrieve_store_class(store)
          # require_relative cannot be used here because the class might be
          # provided by another gem, like redis-activesupport for example.
          require "active_support/cache/#{store}"
        rescue LoadError => e
          raise "Could not find cache store adapter for #{store} (#{e})"
        else
          ActiveSupport::Cache.const_get(store.to_s.camelize)
        end
    end

    # = Active Support \Cache \Store
    #
    # An abstract cache store class. There are multiple cache store
    # implementations, each having its own additional features. See the classes
    # under the ActiveSupport::Cache module, e.g.
    # ActiveSupport::Cache::MemCacheStore. MemCacheStore is currently the most
    # popular cache store for large production websites.
    #
    # Some implementations may not support all methods beyond the basic cache
    # methods of #fetch, #write, #read, #exist?, and #delete.
    #
    # +ActiveSupport::Cache::Store+ can store any Ruby object that is supported
    # by its +coder+'s +dump+ and +load+ methods.
    #
    #   cache = ActiveSupport::Cache::MemoryStore.new
    #
    #   cache.read('city')   # => nil
    #   cache.write('city', "Duckburgh") # => true
    #   cache.read('city')   # => "Duckburgh"
    #
    #   cache.write('not serializable', Proc.new {}) # => TypeError
    #
    # Keys are always translated into Strings and are case sensitive. When an
    # object is specified as a key and has a +cache_key+ method defined, this
    # method will be called to define the key.  Otherwise, the +to_param+
    # method will be called. Hashes and Arrays can also be used as keys. The
    # elements will be delimited by slashes, and the elements within a Hash
    # will be sorted by key so they are consistent.
    #
    #   cache.read('city') == cache.read(:city)   # => true
    #
    # Nil values can be cached.
    #
    # If your cache is on a shared infrastructure, you can define a namespace
    # for your cache entries. If a namespace is defined, it will be prefixed on
    # to every key. The namespace can be either a static value or a Proc. If it
    # is a Proc, it will be invoked when each key is evaluated so that you can
    # use application logic to invalidate keys.
    #
    #   cache.namespace = -> { @last_mod_time }  # Set the namespace to a variable
    #   @last_mod_time = Time.now  # Invalidate the entire cache by changing namespace
    #
    class Store
      cattr_accessor :logger, instance_writer: true
      cattr_accessor :raise_on_invalid_cache_expiration_time, default: false

      attr_reader :silence, :options
      alias :silence? :silence

      class << self
        private
          DEFAULT_POOL_OPTIONS = { size: 5, timeout: 5 }.freeze
          private_constant :DEFAULT_POOL_OPTIONS

          def retrieve_pool_options(options)
            if options.key?(:pool)
              pool_options = options.delete(:pool)
            else
              pool_options = true
            end

            case pool_options
            when false, nil
              return false
            when true
              pool_options = DEFAULT_POOL_OPTIONS
            when Hash
              pool_options[:size] = Integer(pool_options[:size]) if pool_options.key?(:size)
              pool_options[:timeout] = Float(pool_options[:timeout]) if pool_options.key?(:timeout)
              pool_options = DEFAULT_POOL_OPTIONS.merge(pool_options)
            else
              raise TypeError, "Invalid :pool argument, expected Hash, got: #{pool_options.inspect}"
            end

            pool_options unless pool_options.empty?
          end
      end

      # Creates a new cache.
      #
      # ==== Options
      #
      # [+:namespace+]
      #   Sets the namespace for the cache. This option is especially useful if
      #   your application shares a cache with other applications.
      #
      # [+:serializer+]
      #   The serializer for cached values. Must respond to +dump+ and +load+.
      #
      #   The default serializer depends on the cache format version (set via
      #   +config.active_support.cache_format_version+ when using Rails). The
      #   default serializer for each format version includes a fallback
      #   mechanism to deserialize values from any format version. This behavior
      #   makes it easy to migrate between format versions without invalidating
      #   the entire cache.
      #
      #   You can also specify <tt>serializer: :message_pack</tt> to use a
      #   preconfigured serializer based on ActiveSupport::MessagePack. The
      #   +:message_pack+ serializer includes the same deserialization fallback
      #   mechanism, allowing easy migration from (or to) the default
      #   serializer. The +:message_pack+ serializer may improve performance,
      #   but it requires the +msgpack+ gem.
      #
      # [+:compressor+]
      #   The compressor for serialized cache values. Must respond to +deflate+
      #   and +inflate+.
      #
      #   The default compressor is +Zlib+. To define a new custom compressor
      #   that also decompresses old cache entries, you can check compressed
      #   values for Zlib's <tt>"\x78"</tt> signature:
      #
      #     module MyCompressor
      #       def self.deflate(dumped)
      #         # compression logic... (make sure result does not start with "\x78"!)
      #       end
      #
      #       def self.inflate(compressed)
      #         if compressed.start_with?("\x78")
      #           Zlib.inflate(compressed)
      #         else
      #           # decompression logic...
      #         end
      #       end
      #     end
      #
      #     ActiveSupport::Cache.lookup_store(:redis_cache_store, compressor: MyCompressor)
      #
      # [+:coder+]
      #   The coder for serializing and (optionally) compressing cache entries.
      #   Must respond to +dump+ and +load+.
      #
      #   The default coder composes the serializer and compressor, and includes
      #   some performance optimizations. If you only need to override the
      #   serializer or compressor, you should specify the +:serializer+ or
      #   +:compressor+ options instead.
      #
      #   If the store can handle cache entries directly, you may also specify
      #   <tt>coder: nil</tt> to omit the serializer, compressor, and coder. For
      #   example, if you are using ActiveSupport::Cache::MemoryStore and can
      #   guarantee that cache values will not be mutated, you can specify
      #   <tt>coder: nil</tt> to avoid the overhead of safeguarding against
      #   mutation.
      #
      #   The +:coder+ option is mutually exclusive with the +:serializer+ and
      #   +:compressor+ options. Specifying them together will raise an
      #   +ArgumentError+.
      #
      # Any other specified options are treated as default options for the
      # relevant cache operations, such as #read, #write, and #fetch.
      def initialize(options = nil)
        @options = options ? validate_options(normalize_options(options)) : {}

        @options[:compress] = true unless @options.key?(:compress)
        @options[:compress_threshold] ||= DEFAULT_COMPRESS_LIMIT

        @coder = @options.delete(:coder) do
          legacy_serializer = Cache.format_version < 7.1 && !@options[:serializer]
          serializer = @options.delete(:serializer) || default_serializer
          serializer = Cache::SerializerWithFallback[serializer] if serializer.is_a?(Symbol)
          compressor = @options.delete(:compressor) { Zlib }

          Cache::Coder.new(serializer, compressor, legacy_serializer: legacy_serializer)
        end

        @coder ||= Cache::SerializerWithFallback[:passthrough]

        @coder_supports_compression = @coder.respond_to?(:dump_compressed)
      end

      # Silences the logger.
      def silence!
        @silence = true
        self
      end

      # Silences the logger within a block.
      def mute
        previous_silence, @silence = @silence, true
        yield
      ensure
        @silence = previous_silence
      end

      # Fetches data from the cache, using the given key. If there is data in
      # the cache with the given key, then that data is returned.
      #
      # If there is no such data in the cache (a cache miss), then +nil+ will be
      # returned. However, if a block has been passed, that block will be passed
      # the key and executed in the event of a cache miss. The return value of the
      # block will be written to the cache under the given cache key, and that
      # return value will be returned.
      #
      #   cache.write('today', 'Monday')
      #   cache.fetch('today')  # => "Monday"
      #
      #   cache.fetch('city')   # => nil
      #   cache.fetch('city') do
      #     'Duckburgh'
      #   end
      #   cache.fetch('city')   # => "Duckburgh"
      #
      # ==== Options
      #
      # Internally, +fetch+ calls +read_entry+, and calls +write_entry+ on a
      # cache miss. Thus, +fetch+ supports the same options as #read and #write.
      # Additionally, +fetch+ supports the following options:
      #
      # * <tt>force: true</tt> - Forces a cache "miss," meaning we treat the
      #   cache value as missing even if it's present. Passing a block is
      #   required when +force+ is true so this always results in a cache write.
      #
      #     cache.write('today', 'Monday')
      #     cache.fetch('today', force: true) { 'Tuesday' } # => 'Tuesday'
      #     cache.fetch('today', force: true) # => ArgumentError
      #
      #   The +:force+ option is useful when you're calling some other method to
      #   ask whether you should force a cache write. Otherwise, it's clearer to
      #   just call +write+.
      #
      # * <tt>skip_nil: true</tt> - Prevents caching a nil result:
      #
      #     cache.fetch('foo') { nil }
      #     cache.fetch('bar', skip_nil: true) { nil }
      #     cache.exist?('foo') # => true
      #     cache.exist?('bar') # => false
      #
      # * +:race_condition_ttl+ - Specifies the number of seconds during which
      #   an expired value can be reused while a new value is being generated.
      #   This can be used to prevent race conditions when cache entries expire,
      #   by preventing multiple processes from simultaneously regenerating the
      #   same entry (also known as the dog pile effect).
      #
      #   When a process encounters a cache entry that has expired less than
      #   +:race_condition_ttl+ seconds ago, it will bump the expiration time by
      #   +:race_condition_ttl+ seconds before generating a new value. During
      #   this extended time window, while the process generates a new value,
      #   other processes will continue to use the old value. After the first
      #   process writes the new value, other processes will then use it.
      #
      #   If the first process errors out while generating a new value, another
      #   process can try to generate a new value after the extended time window
      #   has elapsed.
      #
      #     # Set all values to expire after one second.
      #     cache = ActiveSupport::Cache::MemoryStore.new(expires_in: 1)
      #
      #     cache.write("foo", "original value")
      #     val_1 = nil
      #     val_2 = nil
      #     p cache.read("foo") # => "original value"
      #
      #     sleep 1 # wait until the cache expires
      #
      #     t1 = Thread.new do
      #       # fetch does the following:
      #       # 1. gets an recent expired entry
      #       # 2. extends the expiry by 2 seconds (race_condition_ttl)
      #       # 3. regenerates the new value
      #       val_1 = cache.fetch("foo", race_condition_ttl: 2) do
      #         sleep 1
      #         "new value 1"
      #       end
      #     end
      #
      #     # Wait until t1 extends the expiry of the entry
      #     # but before generating the new value
      #     sleep 0.1
      #
      #     val_2 = cache.fetch("foo", race_condition_ttl: 2) do
      #       # This block won't be executed because t1 extended the expiry
      #       "new value 2"
      #     end
      #
      #     t1.join
      #
      #     p val_1 # => "new value 1"
      #     p val_2 # => "original value"
      #     p cache.fetch("foo") # => "new value 1"
      #
      #     # The entry requires 3 seconds to expire (expires_in + race_condition_ttl)
      #     # We have waited 2 seconds already (sleep(1) + t1.join) thus we need to wait 1
      #     # more second to see the entry expire.
      #     sleep 1
      #
      #     p cache.fetch("foo") # => nil
      #
      # ==== Dynamic Options
      #
      # In some cases it may be necessary to dynamically compute options based
      # on the cached value. To support this, an ActiveSupport::Cache::WriteOptions
      # instance is passed as the second argument to the block. For example:
      #
      #     cache.fetch("authentication-token:#{user.id}") do |key, options|
      #       token = authenticate_to_service
      #       options.expires_at = token.expires_at
      #       token
      #     end
      #
      def fetch(name, options = nil, &block)
        if block_given?
          options = merged_options(options)
          key = normalize_key(name, options)

          entry = nil
          unless options[:force]
            instrument(:read, key, options) do |payload|
              cached_entry = read_entry(key, **options, event: payload)
              entry = handle_expired_entry(cached_entry, key, options)
              if entry
                if entry.mismatched?(normalize_version(name, options))
                  entry = nil
                else
                  begin
                    entry.value
                  rescue DeserializationError
                    entry = nil
                  end
                end
              end
              payload[:super_operation] = :fetch if payload
              payload[:hit] = !!entry if payload
            end
          end

          if entry
            get_entry_value(entry, name, options)
          else
            save_block_result_to_cache(name, key, options, &block)
          end
        elsif options && options[:force]
          raise ArgumentError, "Missing block: Calling `Cache#fetch` with `force: true` requires a block."
        else
          read(name, options)
        end
      end

      # Reads data from the cache, using the given key. If there is data in
      # the cache with the given key, then that data is returned. Otherwise,
      # +nil+ is returned.
      #
      # Note, if data was written with the <tt>:expires_in</tt> or
      # <tt>:version</tt> options, both of these conditions are applied before
      # the data is returned.
      #
      # ==== Options
      #
      # * +:namespace+ - Replace the store namespace for this call.
      # * +:version+ - Specifies a version for the cache entry. If the cached
      #   version does not match the requested version, the read will be treated
      #   as a cache miss. This feature is used to support recyclable cache keys.
      #
      # Other options will be handled by the specific cache store implementation.
      def read(name, options = nil)
        options = merged_options(options)
        key     = normalize_key(name, options)
        version = normalize_version(name, options)

        instrument(:read, key, options) do |payload|
          entry = read_entry(key, **options, event: payload)

          if entry
            if entry.expired?
              delete_entry(key, **options)
              payload[:hit] = false if payload
              nil
            elsif entry.mismatched?(version)
              payload[:hit] = false if payload
              nil
            else
              payload[:hit] = true if payload
              begin
                entry.value
              rescue DeserializationError
                payload[:hit] = false
                nil
              end
            end
          else
            payload[:hit] = false if payload
            nil
          end
        end
      end

      # Reads multiple values at once from the cache. Options can be passed
      # in the last argument.
      #
      # Some cache implementation may optimize this method.
      #
      # Returns a hash mapping the names provided to the values found.
      def read_multi(*names)
        return {} if names.empty?

        options = names.extract_options!
        options = merged_options(options)
        keys    = names.map { |name| normalize_key(name, options) }

        instrument_multi :read_multi, keys, options do |payload|
          read_multi_entries(names, **options, event: payload).tap do |results|
            payload[:hits] = results.keys.map { |name| normalize_key(name, options) }
          end
        end
      end

      # Cache Storage API to write multiple values at once.
      def write_multi(hash, options = nil)
        return hash if hash.empty?

        options = merged_options(options)
        normalized_hash = hash.transform_keys { |key| normalize_key(key, options) }

        instrument_multi :write_multi, normalized_hash, options do |payload|
          entries = hash.each_with_object({}) do |(name, value), memo|
            memo[normalize_key(name, options)] = Entry.new(value, **options.merge(version: normalize_version(name, options)))
          end

          write_multi_entries entries, **options
        end
      end

      # Fetches data from the cache, using the given keys. If there is data in
      # the cache with the given keys, then that data is returned. Otherwise,
      # the supplied block is called for each key for which there was no data,
      # and the result will be written to the cache and returned.
      # Therefore, you need to pass a block that returns the data to be written
      # to the cache. If you do not want to write the cache when the cache is
      # not found, use #read_multi.
      #
      # Returns a hash with the data for each of the names. For example:
      #
      #   cache.write("bim", "bam")
      #   cache.fetch_multi("bim", "unknown_key") do |key|
      #     "Fallback value for key: #{key}"
      #   end
      #   # => { "bim" => "bam",
      #   #      "unknown_key" => "Fallback value for key: unknown_key" }
      #
      # You may also specify additional options via the +options+ argument. See #fetch for details.
      # Other options are passed to the underlying cache implementation. For example:
      #
      #   cache.fetch_multi("fizz", expires_in: 5.seconds) do |key|
      #     "buzz"
      #   end
      #   # => {"fizz"=>"buzz"}
      #   cache.read("fizz")
      #   # => "buzz"
      #   sleep(6)
      #   cache.read("fizz")
      #   # => nil
      def fetch_multi(*names)
        raise ArgumentError, "Missing block: `Cache#fetch_multi` requires a block." unless block_given?
        return {} if names.empty?

        options = names.extract_options!
        options = merged_options(options)
        keys    = names.map { |name| normalize_key(name, options) }
        writes  = {}
        ordered = instrument_multi :read_multi, keys, options do |payload|
          if options[:force]
            reads = {}
          else
            reads = read_multi_entries(names, **options)
          end

          ordered = names.index_with do |name|
            reads.fetch(name) { writes[name] = yield(name) }
          end
          writes.compact! if options[:skip_nil]

          payload[:hits] = reads.keys.map { |name| normalize_key(name, options) }
          payload[:super_operation] = :fetch_multi

          ordered
        end

        write_multi(writes, options)

        ordered
      end

      # Writes the value to the cache with the key. The value must be supported
      # by the +coder+'s +dump+ and +load+ methods.
      #
      # Returns +true+ if the write succeeded, +nil+ if there was an error talking
      # to the cache backend, or +false+ if the write failed for another reason.
      #
      # By default, cache entries larger than 1kB are compressed. Compression
      # allows more data to be stored in the same memory footprint, leading to
      # fewer cache evictions and higher hit rates.
      #
      # ==== Options
      #
      # * <tt>compress: false</tt> - Disables compression of the cache entry.
      #
      # * +:compress_threshold+ - The compression threshold, specified in bytes.
      #   \Cache entries larger than this threshold will be compressed. Defaults
      #   to +1.kilobyte+.
      #
      # * +:expires_in+ - Sets a relative expiration time for the cache entry,
      #   specified in seconds. +:expire_in+ and +:expired_in+ are aliases for
      #   +:expires_in+.
      #
      #     cache = ActiveSupport::Cache::MemoryStore.new(expires_in: 5.minutes)
      #     cache.write(key, value, expires_in: 1.minute) # Set a lower value for one entry
      #
      # * +:expires_at+ - Sets an absolute expiration time for the cache entry.
      #
      #     cache = ActiveSupport::Cache::MemoryStore.new
      #     cache.write(key, value, expires_at: Time.now.at_end_of_hour)
      #
      # * +:version+ - Specifies a version for the cache entry. When reading
      #   from the cache, if the cached version does not match the requested
      #   version, the read will be treated as a cache miss. This feature is
      #   used to support recyclable cache keys.
      #
      # Other options will be handled by the specific cache store implementation.
      def write(name, value, options = nil)
        options = merged_options(options)
        key = normalize_key(name, options)

        instrument(:write, key, options) do
          entry = Entry.new(value, **options.merge(version: normalize_version(name, options)))
          write_entry(key, entry, **options)
        end
      end

      # Deletes an entry in the cache. Returns +true+ if an entry is deleted
      # and +false+ otherwise.
      #
      # Options are passed to the underlying cache implementation.
      def delete(name, options = nil)
        options = merged_options(options)
        key = normalize_key(name, options)

        instrument(:delete, key, options) do
          delete_entry(key, **options)
        end
      end

      # Deletes multiple entries in the cache. Returns the number of deleted
      # entries.
      #
      # Options are passed to the underlying cache implementation.
      def delete_multi(names, options = nil)
        return 0 if names.empty?

        options = merged_options(options)
        names.map! { |key| normalize_key(key, options) }

        instrument_multi(:delete_multi, names, options) do
          delete_multi_entries(names, **options)
        end
      end

      # Returns +true+ if the cache contains an entry for the given key.
      #
      # Options are passed to the underlying cache implementation.
      def exist?(name, options = nil)
        options = merged_options(options)
        key = normalize_key(name, options)

        instrument(:exist?, key) do |payload|
          entry = read_entry(key, **options, event: payload)
          (entry && !entry.expired? && !entry.mismatched?(normalize_version(name, options))) || false
        end
      end

      def new_entry(value, options = nil) # :nodoc:
        Entry.new(value, **merged_options(options))
      end

      # Deletes all entries with keys matching the pattern.
      #
      # Options are passed to the underlying cache implementation.
      #
      # Some implementations may not support this method.
      def delete_matched(matcher, options = nil)
        raise NotImplementedError.new("#{self.class.name} does not support delete_matched")
      end

      # Increments an integer value in the cache.
      #
      # Options are passed to the underlying cache implementation.
      #
      # Some implementations may not support this method.
      def increment(name, amount = 1, options = nil)
        raise NotImplementedError.new("#{self.class.name} does not support increment")
      end

      # Decrements an integer value in the cache.
      #
      # Options are passed to the underlying cache implementation.
      #
      # Some implementations may not support this method.
      def decrement(name, amount = 1, options = nil)
        raise NotImplementedError.new("#{self.class.name} does not support decrement")
      end

      # Cleans up the cache by removing expired entries.
      #
      # Options are passed to the underlying cache implementation.
      #
      # Some implementations may not support this method.
      def cleanup(options = nil)
        raise NotImplementedError.new("#{self.class.name} does not support cleanup")
      end

      # Clears the entire cache. Be careful with this method since it could
      # affect other processes if shared cache is being used.
      #
      # The options hash is passed to the underlying cache implementation.
      #
      # Some implementations may not support this method.
      def clear(options = nil)
        raise NotImplementedError.new("#{self.class.name} does not support clear")
      end

      private
        def default_serializer
          case Cache.format_version
          when 7.0
            Cache::SerializerWithFallback[:marshal_7_0]
          when 7.1
            Cache::SerializerWithFallback[:marshal_7_1]
          else
            raise ArgumentError, "Unrecognized ActiveSupport::Cache.format_version: #{Cache.format_version.inspect}"
          end
        end

        # Adds the namespace defined in the options to a pattern designed to
        # match keys. Implementations that support delete_matched should call
        # this method to translate a pattern that matches names into one that
        # matches namespaced keys.
        def key_matcher(pattern, options) # :doc:
          prefix = options[:namespace].is_a?(Proc) ? options[:namespace].call : options[:namespace]
          if prefix
            source = pattern.source
            if source.start_with?("^")
              source = source[1, source.length]
            else
              source = ".*#{source[0, source.length]}"
            end
            Regexp.new("^#{Regexp.escape(prefix)}:#{source}", pattern.options)
          else
            pattern
          end
        end

        # Reads an entry from the cache implementation. Subclasses must implement
        # this method.
        def read_entry(key, **options)
          raise NotImplementedError.new
        end

        # Writes an entry to the cache implementation. Subclasses must implement
        # this method.
        def write_entry(key, entry, **options)
          raise NotImplementedError.new
        end

        def serialize_entry(entry, **options)
          options = merged_options(options)
          if @coder_supports_compression && options[:compress]
            @coder.dump_compressed(entry, options[:compress_threshold])
          else
            @coder.dump(entry)
          end
        end

        def deserialize_entry(payload, **)
          payload.nil? ? nil : @coder.load(payload)
        rescue DeserializationError
          nil
        end

        # Reads multiple entries from the cache implementation. Subclasses MAY
        # implement this method.
        def read_multi_entries(names, **options)
          names.each_with_object({}) do |name, results|
            key   = normalize_key(name, options)
            entry = read_entry(key, **options)

            next unless entry

            version = normalize_version(name, options)

            if entry.expired?
              delete_entry(key, **options)
            elsif !entry.mismatched?(version)
              results[name] = entry.value
            end
          end
        end

        # Writes multiple entries to the cache implementation. Subclasses MAY
        # implement this method.
        def write_multi_entries(hash, **options)
          hash.each do |key, entry|
            write_entry key, entry, **options
          end
        end

        # Deletes an entry from the cache implementation. Subclasses must
        # implement this method.
        def delete_entry(key, **options)
          raise NotImplementedError.new
        end

        # Deletes multiples entries in the cache implementation. Subclasses MAY
        # implement this method.
        def delete_multi_entries(entries, **options)
          entries.count { |key| delete_entry(key, **options) }
        end

        # Merges the default options with ones specific to a method call.
        def merged_options(call_options)
          if call_options
            call_options = normalize_options(call_options)
            if call_options.key?(:expires_in) && call_options.key?(:expires_at)
              raise ArgumentError, "Either :expires_in or :expires_at can be supplied, but not both"
            end

            expires_at = call_options.delete(:expires_at)
            call_options[:expires_in] = (expires_at - Time.now) if expires_at

            if call_options[:expires_in].is_a?(Time)
              expires_in = call_options[:expires_in]
              raise ArgumentError.new("expires_in parameter should not be a Time. Did you mean to use expires_at? Got: #{expires_in}")
            end
            if call_options[:expires_in]&.negative?
              expires_in = call_options.delete(:expires_in)
              handle_invalid_expires_in("Cache expiration time is invalid, cannot be negative: #{expires_in}")
            end

            if options.empty?
              call_options
            else
              options.merge(call_options)
            end
          else
            options
          end
        end

        def handle_invalid_expires_in(message)
          error = ArgumentError.new(message)
          if ActiveSupport::Cache::Store.raise_on_invalid_cache_expiration_time
            raise error
          else
            ActiveSupport.error_reporter&.report(error, handled: true, severity: :warning)
            logger.error("#{error.class}: #{error.message}") if logger
          end
        end

        # Normalize aliased options to their canonical form
        def normalize_options(options)
          options = options.dup
          OPTION_ALIASES.each do |canonical_name, aliases|
            alias_key = aliases.detect { |key| options.key?(key) }
            options[canonical_name] ||= options[alias_key] if alias_key
            options.except!(*aliases)
          end

          options
        end

        def validate_options(options)
          if options.key?(:coder) && options[:serializer]
            raise ArgumentError, "Cannot specify :serializer and :coder options together"
          end

          if options.key?(:coder) && options[:compressor]
            raise ArgumentError, "Cannot specify :compressor and :coder options together"
          end

          if Cache.format_version < 7.1 && !options[:serializer] && options[:compressor]
            raise ArgumentError, "Cannot specify :compressor option when using" \
              " default serializer and cache format version is < 7.1"
          end

          options
        end

        # Expands and namespaces the cache key.
        # Raises an exception when the key is +nil+ or an empty string.
        # May be overridden by cache stores to do additional normalization.
        def normalize_key(key, options = nil)
          str_key = expanded_key(key)
          raise(ArgumentError, "key cannot be blank") if !str_key || str_key.empty?

          namespace_key str_key, options
        end

        # Prefix the key with a namespace string:
        #
        #   namespace_key 'foo', namespace: 'cache'
        #   # => 'cache:foo'
        #
        # With a namespace block:
        #
        #   namespace_key 'foo', namespace: -> { 'cache' }
        #   # => 'cache:foo'
        def namespace_key(key, call_options = nil)
          namespace = if call_options&.key?(:namespace)
            call_options[:namespace]
          else
            options[:namespace]
          end

          if namespace.respond_to?(:call)
            namespace = namespace.call
          end

          if key && key.encoding != Encoding::UTF_8
            key = key.dup.force_encoding(Encoding::UTF_8)
          end

          if namespace
            "#{namespace}:#{key}"
          else
            key
          end
        end

        # Expands key to be a consistent string value. Invokes +cache_key+ if
        # object responds to +cache_key+. Otherwise, +to_param+ method will be
        # called. If the key is a Hash, then keys will be sorted alphabetically.
        def expanded_key(key)
          return key.cache_key.to_s if key.respond_to?(:cache_key)

          case key
          when Array
            if key.size > 1
              key.collect { |element| expanded_key(element) }
            else
              expanded_key(key.first)
            end
          when Hash
            key.collect { |k, v| "#{k}=#{v}" }.sort!
          else
            key
          end.to_param
        end

        def normalize_version(key, options = nil)
          (options && options[:version].try(:to_param)) || expanded_version(key)
        end

        def expanded_version(key)
          case
          when key.respond_to?(:cache_version) then key.cache_version.to_param
          when key.is_a?(Array)                then key.map { |element| expanded_version(element) }.tap(&:compact!).to_param
          when key.respond_to?(:to_a)          then expanded_version(key.to_a)
          end
        end

        def instrument(operation, key, options = nil, &block)
          _instrument(operation, key: key, options: options, &block)
        end

        def instrument_multi(operation, keys, options = nil, &block)
          _instrument(operation, multi: true, key: keys, options: options, &block)
        end

        def _instrument(operation, multi: false, options: nil, **payload, &block)
          if logger && logger.debug? && !silence?
            debug_key =
              if multi
                ": #{payload[:key].size} key(s) specified"
              elsif payload[:key]
                ": #{payload[:key]}"
              end

            debug_options = " (#{options.inspect})" unless options.blank?

            logger.debug "Cache #{operation}#{debug_key}#{debug_options}"
          end

          payload[:store] = self.class.name
          payload.merge!(options) if options.is_a?(Hash)
          ActiveSupport::Notifications.instrument("cache_#{operation}.active_support", payload) do
            block&.call(payload)
          end
        end

        def handle_expired_entry(entry, key, options)
          if entry && entry.expired?
            race_ttl = options[:race_condition_ttl].to_i
            if (race_ttl > 0) && (Time.now.to_f - entry.expires_at <= race_ttl)
              # When an entry has a positive :race_condition_ttl defined, put the stale entry back into the cache
              # for a brief period while the entry is being recalculated.
              entry.expires_at = Time.now.to_f + race_ttl
              write_entry(key, entry, **options, expires_in: race_ttl * 2)
            else
              delete_entry(key, **options)
            end
            entry = nil
          end
          entry
        end

        def get_entry_value(entry, name, options)
          instrument(:fetch_hit, name, options)
          entry.value
        end

        def save_block_result_to_cache(name, key, options)
          options = options.dup

          result = instrument(:generate, key, options) do
            yield(name, WriteOptions.new(options))
          end

          write(name, result, options) unless result.nil? && options[:skip_nil]
          result
        end
    end

    # Enables the dynamic configuration of Cache entry options while ensuring
    # that conflicting options are not both set. When a block is given to
    # ActiveSupport::Cache::Store#fetch, the second argument will be an
    # instance of +WriteOptions+.
    class WriteOptions
      def initialize(options) # :nodoc:
        @options = options
      end

      def version
        @options[:version]
      end

      def version=(version)
        @options[:version] = version
      end

      def expires_in
        @options[:expires_in]
      end

      # Sets the Cache entry's +expires_in+ value. If an +expires_at+ option was
      # previously set, this will unset it since +expires_in+ and +expires_at+
      # cannot both be set.
      def expires_in=(expires_in)
        @options.delete(:expires_at)
        @options[:expires_in] = expires_in
      end

      def expires_at
        @options[:expires_at]
      end

      # Sets the Cache entry's +expires_at+ value. If an +expires_in+ option was
      # previously set, this will unset it since +expires_at+ and +expires_in+
      # cannot both be set.
      def expires_at=(expires_at)
        @options.delete(:expires_in)
        @options[:expires_at] = expires_at
      end
    end
  end
end
