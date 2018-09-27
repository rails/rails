# frozen_string_literal: true

require "zlib"
require "active_support/core_ext/array/extract_options"
require "active_support/core_ext/array/wrap"
require "active_support/core_ext/module/attribute_accessors"
require "active_support/core_ext/numeric/bytes"
require "active_support/core_ext/numeric/time"
require "active_support/core_ext/object/to_param"
require "active_support/core_ext/string/inflections"

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
    UNIVERSAL_OPTIONS = [:namespace, :compress, :compress_threshold, :expires_in, :race_condition_ttl]

    module Strategy
      autoload :LocalCache, "active_support/cache/strategy/local_cache"
    end

    class << self
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
      def lookup_store(*store_option)
        store, *parameters = *Array.wrap(store_option).flatten

        case store
        when Symbol
          retrieve_store_class(store).new(*parameters)
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
        expanded_cache_key = (namespace ? "#{namespace}/" : "").dup

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

    # An abstract cache store class. There are multiple cache store
    # implementations, each having its own additional features. See the classes
    # under the ActiveSupport::Cache module, e.g.
    # ActiveSupport::Cache::MemCacheStore. MemCacheStore is currently the most
    # popular cache store for large production websites.
    #
    # Some implementations may not support all methods beyond the basic cache
    # methods of +fetch+, +write+, +read+, +exist?+, and +delete+.
    #
    # ActiveSupport::Cache::Store can store any serializable Ruby object.
    #
    #   cache = ActiveSupport::Cache::MemoryStore.new
    #
    #   cache.read('city')   # => nil
    #   cache.write('city', "Duckburgh")
    #   cache.read('city')   # => "Duckburgh"
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
    # Cached data larger than 1kB are compressed by default. To turn off
    # compression, pass <tt>compress: false</tt> to the initializer or to
    # individual +fetch+ or +write+ method calls. The 1kB compression
    # threshold is configurable with the <tt>:compress_threshold</tt> option,
    # specified in bytes.
    class Store
      cattr_accessor :logger, instance_writer: true

      attr_reader :silence, :options
      alias :silence? :silence

      class << self
        private
          def retrieve_pool_options(options)
            {}.tap do |pool_options|
              pool_options[:size] = options.delete(:pool_size) if options[:pool_size]
              pool_options[:timeout] = options.delete(:pool_timeout) if options[:pool_timeout]
            end
          end

          def ensure_connection_pool_added!
            require "connection_pool"
          rescue LoadError => e
            $stderr.puts "You don't have connection_pool installed in your application. Please add it to your Gemfile and run bundle install"
            raise e
          end
      end

      # Creates a new cache. The options will be passed to any write method calls
      # except for <tt>:namespace</tt> which can be used to set the global
      # namespace for the cache.
      def initialize(options = nil)
        @options = options ? options.dup : {}
      end

      # Silences the logger.
      def silence!
        @silence = true
        self
      end

      # Silences the logger within a block.
      def mute
        previous_silence, @silence = defined?(@silence) && @silence, true
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
      # You may also specify additional options via the +options+ argument.
      # Setting <tt>force: true</tt> forces a cache "miss," meaning we treat
      # the cache value as missing even if it's present. Passing a block is
      # required when +force+ is true so this always results in a cache write.
      #
      #   cache.write('today', 'Monday')
      #   cache.fetch('today', force: true) { 'Tuesday' } # => 'Tuesday'
      #   cache.fetch('today', force: true) # => ArgumentError
      #
      # The +:force+ option is useful when you're calling some other method to
      # ask whether you should force a cache write. Otherwise, it's clearer to
      # just call <tt>Cache#write</tt>.
      #
      # Setting <tt>skip_nil: true</tt> will not cache nil result:
      #
      #   cache.fetch('foo') { nil }
      #   cache.fetch('bar', skip_nil: true) { nil }
      #   cache.exist?('foo') # => true
      #   cache.exist?('bar') # => false
      #
      #
      # Setting <tt>compress: false</tt> disables compression of the cache entry.
      #
      # Setting <tt>:expires_in</tt> will set an expiration time on the cache.
      # All caches support auto-expiring content after a specified number of
      # seconds. This value can be specified as an option to the constructor
      # (in which case all entries will be affected), or it can be supplied to
      # the +fetch+ or +write+ method to effect just one entry.
      #
      #   cache = ActiveSupport::Cache::MemoryStore.new(expires_in: 5.minutes)
      #   cache.write(key, value, expires_in: 1.minute) # Set a lower value for one entry
      #
      # Setting <tt>:version</tt> verifies the cache stored under <tt>name</tt>
      # is of the same version. nil is returned on mismatches despite contents.
      # This feature is used to support recyclable cache keys.
      #
      # Setting <tt>:race_condition_ttl</tt> is very useful in situations where
      # a cache entry is used very frequently and is under heavy load. If a
      # cache expires and due to heavy load several different processes will try
      # to read data natively and then they all will try to write to cache. To
      # avoid that case the first process to find an expired cache entry will
      # bump the cache expiration time by the value set in <tt>:race_condition_ttl</tt>.
      # Yes, this process is extending the time for a stale value by another few
      # seconds. Because of extended life of the previous cache, other processes
      # will continue to use slightly stale data for a just a bit longer. In the
      # meantime that first process will go ahead and will write into cache the
      # new value. After that all the processes will start getting the new value.
      # The key is to keep <tt>:race_condition_ttl</tt> small.
      #
      # If the process regenerating the entry errors out, the entry will be
      # regenerated after the specified number of seconds. Also note that the
      # life of stale cache is extended only if it expired recently. Otherwise
      # a new value is generated and <tt>:race_condition_ttl</tt> does not play
      # any role.
      #
      #   # Set all values to expire after one minute.
      #   cache = ActiveSupport::Cache::MemoryStore.new(expires_in: 1.minute)
      #
      #   cache.write('foo', 'original value')
      #   val_1 = nil
      #   val_2 = nil
      #   sleep 60
      #
      #   Thread.new do
      #     val_1 = cache.fetch('foo', race_condition_ttl: 10.seconds) do
      #       sleep 1
      #       'new value 1'
      #     end
      #   end
      #
      #   Thread.new do
      #     val_2 = cache.fetch('foo', race_condition_ttl: 10.seconds) do
      #       'new value 2'
      #     end
      #   end
      #
      #   cache.fetch('foo') # => "original value"
      #   sleep 10 # First thread extended the life of cache by another 10 seconds
      #   cache.fetch('foo') # => "new value 1"
      #   val_1 # => "new value 1"
      #   val_2 # => "original value"
      #
      # Other options will be handled by the specific cache store implementation.
      # Internally, #fetch calls #read_entry, and calls #write_entry on a cache
      # miss. +options+ will be passed to the #read and #write calls.
      #
      # For example, MemCacheStore's #write method supports the +:raw+
      # option, which tells the memcached server to store all values as strings.
      # We can use this option with #fetch too:
      #
      #   cache = ActiveSupport::Cache::MemCacheStore.new
      #   cache.fetch("foo", force: true, raw: true) do
      #     :bar
      #   end
      #   cache.fetch('foo') # => "bar"
      def fetch(name, options = nil)
        if block_given?
          options = merged_options(options)
          key = normalize_key(name, options)

          entry = nil
          instrument(:read, name, options) do |payload|
            cached_entry = read_entry(key, options) unless options[:force]
            entry = handle_expired_entry(cached_entry, key, options)
            entry = nil if entry && entry.mismatched?(normalize_version(name, options))
            payload[:super_operation] = :fetch if payload
            payload[:hit] = !!entry if payload
          end

          if entry
            get_entry_value(entry, name, options)
          else
            save_block_result_to_cache(name, options) { |_name| yield _name }
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
      # Options are passed to the underlying cache implementation.
      def read(name, options = nil)
        options = merged_options(options)
        key     = normalize_key(name, options)
        version = normalize_version(name, options)

        instrument(:read, name, options) do |payload|
          entry = read_entry(key, options)

          if entry
            if entry.expired?
              delete_entry(key, options)
              payload[:hit] = false if payload
              nil
            elsif entry.mismatched?(version)
              payload[:hit] = false if payload
              nil
            else
              payload[:hit] = true if payload
              entry.value
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
        options = names.extract_options!
        options = merged_options(options)

        instrument :read_multi, names, options do |payload|
          read_multi_entries(names, options).tap do |results|
            payload[:hits] = results.keys
          end
        end
      end

      # Cache Storage API to write multiple values at once.
      def write_multi(hash, options = nil)
        options = merged_options(options)

        instrument :write_multi, hash, options do |payload|
          entries = hash.each_with_object({}) do |(name, value), memo|
            memo[normalize_key(name, options)] = Entry.new(value, options.merge(version: normalize_version(name, options)))
          end

          write_multi_entries entries, options
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
      # Options are passed to the underlying cache implementation.
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
      def fetch_multi(*names)
        raise ArgumentError, "Missing block: `Cache#fetch_multi` requires a block." unless block_given?

        options = names.extract_options!
        options = merged_options(options)

        instrument :read_multi, names, options do |payload|
          read_multi_entries(names, options).tap do |results|
            payload[:hits] = results.keys
            payload[:super_operation] = :fetch_multi

            writes = {}

            (names - results.keys).each do |name|
              results[name] = writes[name] = yield(name)
            end

            write_multi writes, options
          end
        end
      end

      # Writes the value to the cache, with the key.
      #
      # Options are passed to the underlying cache implementation.
      def write(name, value, options = nil)
        options = merged_options(options)

        instrument(:write, name, options) do
          entry = Entry.new(value, options.merge(version: normalize_version(name, options)))
          write_entry(normalize_key(name, options), entry, options)
        end
      end

      # Deletes an entry in the cache. Returns +true+ if an entry is deleted.
      #
      # Options are passed to the underlying cache implementation.
      def delete(name, options = nil)
        options = merged_options(options)

        instrument(:delete, name) do
          delete_entry(normalize_key(name, options), options)
        end
      end

      # Returns +true+ if the cache contains an entry for the given key.
      #
      # Options are passed to the underlying cache implementation.
      def exist?(name, options = nil)
        options = merged_options(options)

        instrument(:exist?, name) do
          entry = read_entry(normalize_key(name, options), options)
          (entry && !entry.expired? && !entry.mismatched?(normalize_version(name, options))) || false
        end
      end

      # Deletes all entries with keys matching the pattern.
      #
      # Options are passed to the underlying cache implementation.
      #
      # All implementations may not support this method.
      def delete_matched(matcher, options = nil)
        raise NotImplementedError.new("#{self.class.name} does not support delete_matched")
      end

      # Increments an integer value in the cache.
      #
      # Options are passed to the underlying cache implementation.
      #
      # All implementations may not support this method.
      def increment(name, amount = 1, options = nil)
        raise NotImplementedError.new("#{self.class.name} does not support increment")
      end

      # Decrements an integer value in the cache.
      #
      # Options are passed to the underlying cache implementation.
      #
      # All implementations may not support this method.
      def decrement(name, amount = 1, options = nil)
        raise NotImplementedError.new("#{self.class.name} does not support decrement")
      end

      # Cleanups the cache by removing expired entries.
      #
      # Options are passed to the underlying cache implementation.
      #
      # All implementations may not support this method.
      def cleanup(options = nil)
        raise NotImplementedError.new("#{self.class.name} does not support cleanup")
      end

      # Clears the entire cache. Be careful with this method since it could
      # affect other processes if shared cache is being used.
      #
      # The options hash is passed to the underlying cache implementation.
      #
      # All implementations may not support this method.
      def clear(options = nil)
        raise NotImplementedError.new("#{self.class.name} does not support clear")
      end

      private
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
        def read_entry(key, options)
          raise NotImplementedError.new
        end

        # Writes an entry to the cache implementation. Subclasses must implement
        # this method.
        def write_entry(key, entry, options)
          raise NotImplementedError.new
        end

        # Reads multiple entries from the cache implementation. Subclasses MAY
        # implement this method.
        def read_multi_entries(names, options)
          results = {}
          names.each do |name|
            key     = normalize_key(name, options)
            version = normalize_version(name, options)
            entry   = read_entry(key, options)

            if entry
              if entry.expired?
                delete_entry(key, options)
              elsif entry.mismatched?(version)
                # Skip mismatched versions
              else
                results[name] = entry.value
              end
            end
          end
          results
        end

        # Writes multiple entries to the cache implementation. Subclasses MAY
        # implement this method.
        def write_multi_entries(hash, options)
          hash.each do |key, entry|
            write_entry key, entry, options
          end
        end

        # Deletes an entry from the cache implementation. Subclasses must
        # implement this method.
        def delete_entry(key, options)
          raise NotImplementedError.new
        end

        # Merges the default options with ones specific to a method call.
        def merged_options(call_options)
          if call_options
            if options.empty?
              call_options
            else
              options.merge(call_options)
            end
          else
            options
          end
        end

        # Expands and namespaces the cache key. May be overridden by
        # cache stores to do additional normalization.
        def normalize_key(key, options = nil)
          namespace_key expanded_key(key), options
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
        def namespace_key(key, options = nil)
          options = merged_options(options)
          namespace = options[:namespace]

          if namespace.respond_to?(:call)
            namespace = namespace.call
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
              key = key.collect { |element| expanded_key(element) }
            else
              key = expanded_key(key.first)
            end
          when Hash
            key = key.sort_by { |k, _| k.to_s }.collect { |k, v| "#{k}=#{v}" }
          end

          key.to_param
        end

        def normalize_version(key, options = nil)
          (options && options[:version].try(:to_param)) || expanded_version(key)
        end

        def expanded_version(key)
          case
          when key.respond_to?(:cache_version) then key.cache_version.to_param
          when key.is_a?(Array)                then key.map { |element| expanded_version(element) }.compact.to_param
          when key.respond_to?(:to_a)          then expanded_version(key.to_a)
          end
        end

        def instrument(operation, key, options = nil)
          log { "Cache #{operation}: #{normalize_key(key, options)}#{options.blank? ? "" : " (#{options.inspect})"}" }

          payload = { key: key }
          payload.merge!(options) if options.is_a?(Hash)
          ActiveSupport::Notifications.instrument("cache_#{operation}.active_support", payload) { yield(payload) }
        end

        def log
          return unless logger && logger.debug? && !silence?
          logger.debug(yield)
        end

        def handle_expired_entry(entry, key, options)
          if entry && entry.expired?
            race_ttl = options[:race_condition_ttl].to_i
            if (race_ttl > 0) && (Time.now.to_f - entry.expires_at <= race_ttl)
              # When an entry has a positive :race_condition_ttl defined, put the stale entry back into the cache
              # for a brief period while the entry is being recalculated.
              entry.expires_at = Time.now + race_ttl
              write_entry(key, entry, expires_in: race_ttl * 2)
            else
              delete_entry(key, options)
            end
            entry = nil
          end
          entry
        end

        def get_entry_value(entry, name, options)
          instrument(:fetch_hit, name, options) { }
          entry.value
        end

        def save_block_result_to_cache(name, options)
          result = instrument(:generate, name, options) do
            yield(name)
          end

          write(name, result, options) unless result.nil? && options[:skip_nil]
          result
        end
    end

    # This class is used to represent cache entries. Cache entries have a value, an optional
    # expiration time, and an optional version. The expiration time is used to support the :race_condition_ttl option
    # on the cache. The version is used to support the :version option on the cache for rejecting
    # mismatches.
    #
    # Since cache entries in most instances will be serialized, the internals of this class are highly optimized
    # using short instance variable names that are lazily defined.
    class Entry # :nodoc:
      attr_reader :version

      DEFAULT_COMPRESS_LIMIT = 1.kilobyte

      # Creates a new cache entry for the specified value. Options supported are
      # +:compress+, +:compress_threshold+, +:version+ and +:expires_in+.
      def initialize(value, compress: true, compress_threshold: DEFAULT_COMPRESS_LIMIT, version: nil, expires_in: nil, **)
        @value      = value
        @version    = version
        @created_at = Time.now.to_f
        @expires_in = expires_in && expires_in.to_f

        compress!(compress_threshold) if compress
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
      # <tt>value.size</tt> if the data is compressed.
      def size
        case value
        when NilClass
          0
        when String
          @value.bytesize
        else
          @s ||= Marshal.dump(@value).bytesize
        end
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

      private
        def compress!(compress_threshold)
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
              @value = compressed
              @compressed = true
            end
          end
        end

        def compressed?
          defined?(@compressed)
        end

        def uncompress(value)
          Marshal.load(Zlib::Inflate.inflate(value))
        end
    end
  end
end
