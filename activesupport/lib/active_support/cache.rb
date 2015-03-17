require 'benchmark'
require 'zlib'
require 'active_support/core_ext/array/extract_options'
require 'active_support/core_ext/array/wrap'
require 'active_support/core_ext/benchmark'
require 'active_support/core_ext/module/attribute_accessors'
require 'active_support/core_ext/numeric/bytes'
require 'active_support/core_ext/numeric/time'
require 'active_support/core_ext/object/to_param'
require 'active_support/core_ext/string/inflections'

module ActiveSupport
  # See ActiveSupport::Cache::Store for documentation.
  module Cache
    autoload :FileStore,     'active_support/cache/file_store'
    autoload :MemoryStore,   'active_support/cache/memory_store'
    autoload :MemCacheStore, 'active_support/cache/mem_cache_store'
    autoload :NullStore,     'active_support/cache/null_store'

    # These options mean something to all cache implementations. Individual cache
    # implementations may support additional options.
    UNIVERSAL_OPTIONS = [:namespace, :compress, :compress_threshold, :expires_in, :race_condition_ttl]

    module Strategy
      autoload :LocalCache, 'active_support/cache/strategy/local_cache'
    end

    class << self
      # Creates a new CacheStore object according to the given options.
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
      #   expand_cache_key([:foo, :bar])               # => "foo/bar"
      #   expand_cache_key([:foo, :bar], "namespace")  # => "namespace/foo/bar"
      #
      # The +key+ argument can also respond to +cache_key+ or +to_param+.
      def expand_cache_key(key, namespace = nil)
        expanded_cache_key = namespace ? "#{namespace}/" : ""

        if prefix = ENV["RAILS_CACHE_ID"] || ENV["RAILS_APP_VERSION"]
          expanded_cache_key << "#{prefix}/"
        end

        expanded_cache_key << retrieve_cache_key(key)
        expanded_cache_key
      end

      private
        def retrieve_cache_key(key)
          case
          when key.respond_to?(:cache_key) then key.cache_key
          when key.is_a?(Array)            then key.map { |element| retrieve_cache_key(element) }.to_param
          when key.respond_to?(:to_a)      then retrieve_cache_key(key.to_a)
          else                                  key.to_param
          end.to_s
        end

        # Obtains the specified cache store class, given the name of the +store+.
        # Raises an error when the store class cannot be found.
        def retrieve_store_class(store)
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
    # Caches can also store values in a compressed format to save space and
    # reduce time spent sending data. Since there is overhead, values must be
    # large enough to warrant compression. To turn on compression either pass
    # <tt>compress: true</tt> in the initializer or as an option to +fetch+
    # or +write+. To specify the threshold at which to compress values, set the
    # <tt>:compress_threshold</tt> option. The default threshold is 16K.
    class Store
      cattr_accessor :logger, :instance_writer => true

      attr_reader :silence, :options
      alias :silence? :silence

      # Create a new cache. The options will be passed to any write method calls
      # except for <tt>:namespace</tt> which can be used to set the global
      # namespace for the cache.
      def initialize(options = nil)
        @options = options ? options.dup : {}
      end

      # Silence the logger.
      def silence!
        @silence = true
        self
      end

      # Silence the logger within a block.
      def mute
        previous_silence, @silence = defined?(@silence) && @silence, true
        yield
      ensure
        @silence = previous_silence
      end

      # Set to +true+ if cache stores should be instrumented.
      # Default is +false+.
      def self.instrument=(boolean)
        Thread.current[:instrument_cache_store] = boolean
      end

      def self.instrument
        Thread.current[:instrument_cache_store] || false
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
      # Setting <tt>force: true</tt> will force a cache miss:
      #
      #   cache.write('today', 'Monday')
      #   cache.fetch('today', force: true)  # => nil
      #
      # Setting <tt>:compress</tt> will store a large cache entry set by the call
      # in a compressed format.
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
      # new value. After that all the processes will start getting new value.
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
      #     val_1 = cache.fetch('foo', race_condition_ttl: 10) do
      #       sleep 1
      #       'new value 1'
      #     end
      #   end
      #
      #   Thread.new do
      #     val_2 = cache.fetch('foo', race_condition_ttl: 10) do
      #       'new value 2'
      #     end
      #   end
      #
      #   # val_1 => "new value 1"
      #   # val_2 => "original value"
      #   # sleep 10 # First thread extend the life of cache by another 10 seconds
      #   # cache.fetch('foo') => "new value 1"
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
          key = namespaced_key(name, options)

          cached_entry = find_cached_entry(key, name, options) unless options[:force]
          entry = handle_expired_entry(cached_entry, key, options)

          if entry
            get_entry_value(entry, name, options)
          else
            save_block_result_to_cache(name, options) { |_name| yield _name }
          end
        else
          read(name, options)
        end
      end

      # Fetches data from the cache, using the given key. If there is data in
      # the cache with the given key, then that data is returned. Otherwise,
      # +nil+ is returned.
      #
      # Options are passed to the underlying cache implementation.
      def read(name, options = nil)
        options = merged_options(options)
        key = namespaced_key(name, options)
        instrument(:read, name, options) do |payload|
          entry = read_entry(key, options)
          if entry
            if entry.expired?
              delete_entry(key, options)
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

      # Read multiple values at once from the cache. Options can be passed
      # in the last argument.
      #
      # Some cache implementation may optimize this method.
      #
      # Returns a hash mapping the names provided to the values found.
      def read_multi(*names)
        options = names.extract_options!
        options = merged_options(options)
        results = {}
        names.each do |name|
          key = namespaced_key(name, options)
          entry = read_entry(key, options)
          if entry
            if entry.expired?
              delete_entry(key, options)
            else
              results[name] = entry.value
            end
          end
        end
        results
      end

      # Fetches data from the cache, using the given keys. If there is data in
      # the cache with the given keys, then that data is returned. Otherwise,
      # the supplied block is called for each key for which there was no data,
      # and the result will be written to the cache and returned.
      #
      # Options are passed to the underlying cache implementation.
      #
      # Returns an array with the data for each of the names. For example:
      #
      #   cache.write("bim", "bam")
      #   cache.fetch_multi("bim", "boom") {|key| key * 2 }
      #   # => ["bam", "boomboom"]
      #
      def fetch_multi(*names)
        options = names.extract_options!
        options = merged_options(options)

        results = read_multi(*names, options)

        names.map do |name|
          results.fetch(name) do
            value = yield name
            write(name, value, options)
            value
          end
        end
      end

      # Writes the value to the cache, with the key.
      #
      # Options are passed to the underlying cache implementation.
      def write(name, value, options = nil)
        options = merged_options(options)

        instrument(:write, name, options) do
          entry = Entry.new(value, options)
          write_entry(namespaced_key(name, options), entry, options)
        end
      end

      # Deletes an entry in the cache. Returns +true+ if an entry is deleted.
      #
      # Options are passed to the underlying cache implementation.
      def delete(name, options = nil)
        options = merged_options(options)

        instrument(:delete, name) do
          delete_entry(namespaced_key(name, options), options)
        end
      end

      # Returns +true+ if the cache contains an entry for the given key.
      #
      # Options are passed to the underlying cache implementation.
      def exist?(name, options = nil)
        options = merged_options(options)

        instrument(:exist?, name) do
          entry = read_entry(namespaced_key(name, options), options)
          (entry && !entry.expired?) || false
        end
      end

      # Delete all entries with keys matching the pattern.
      #
      # Options are passed to the underlying cache implementation.
      #
      # All implementations may not support this method.
      def delete_matched(matcher, options = nil)
        raise NotImplementedError.new("#{self.class.name} does not support delete_matched")
      end

      # Increment an integer value in the cache.
      #
      # Options are passed to the underlying cache implementation.
      #
      # All implementations may not support this method.
      def increment(name, amount = 1, options = nil)
        raise NotImplementedError.new("#{self.class.name} does not support increment")
      end

      # Decrement an integer value in the cache.
      #
      # Options are passed to the underlying cache implementation.
      #
      # All implementations may not support this method.
      def decrement(name, amount = 1, options = nil)
        raise NotImplementedError.new("#{self.class.name} does not support decrement")
      end

      # Cleanup the cache by removing expired entries.
      #
      # Options are passed to the underlying cache implementation.
      #
      # All implementations may not support this method.
      def cleanup(options = nil)
        raise NotImplementedError.new("#{self.class.name} does not support cleanup")
      end

      # Clear the entire cache. Be careful with this method since it could
      # affect other processes if shared cache is being used.
      #
      # The options hash is passed to the underlying cache implementation.
      #
      # All implementations may not support this method.
      def clear(options = nil)
        raise NotImplementedError.new("#{self.class.name} does not support clear")
      end

      protected
        # Add the namespace defined in the options to a pattern designed to
        # match keys. Implementations that support delete_matched should call
        # this method to translate a pattern that matches names into one that
        # matches namespaced keys.
        def key_matcher(pattern, options)
          prefix = options[:namespace].is_a?(Proc) ? options[:namespace].call : options[:namespace]
          if prefix
            source = pattern.source
            if source.start_with?('^')
              source = source[1, source.length]
            else
              source = ".*#{source[0, source.length]}"
            end
            Regexp.new("^#{Regexp.escape(prefix)}:#{source}", pattern.options)
          else
            pattern
          end
        end

        # Read an entry from the cache implementation. Subclasses must implement
        # this method.
        def read_entry(key, options) # :nodoc:
          raise NotImplementedError.new
        end

        # Write an entry to the cache implementation. Subclasses must implement
        # this method.
        def write_entry(key, entry, options) # :nodoc:
          raise NotImplementedError.new
        end

        # Delete an entry from the cache implementation. Subclasses must
        # implement this method.
        def delete_entry(key, options) # :nodoc:
          raise NotImplementedError.new
        end

      private
        # Merge the default options with ones specific to a method call.
        def merged_options(call_options) # :nodoc:
          if call_options
            options.merge(call_options)
          else
            options.dup
          end
        end

        # Expand key to be a consistent string value. Invoke +cache_key+ if
        # object responds to +cache_key+. Otherwise, +to_param+ method will be
        # called. If the key is a Hash, then keys will be sorted alphabetically.
        def expanded_key(key) # :nodoc:
          return key.cache_key.to_s if key.respond_to?(:cache_key)

          case key
          when Array
            if key.size > 1
              key = key.collect{|element| expanded_key(element)}
            else
              key = key.first
            end
          when Hash
            key = key.sort_by { |k,_| k.to_s }.collect{|k,v| "#{k}=#{v}"}
          end

          key.to_param
        end

        # Prefix a key with the namespace. Namespace and key will be delimited
        # with a colon.
        def namespaced_key(key, options)
          key = expanded_key(key)
          namespace = options[:namespace] if options
          prefix = namespace.is_a?(Proc) ? namespace.call : namespace
          key = "#{prefix}:#{key}" if prefix
          key
        end

        def instrument(operation, key, options = nil)
          log(operation, key, options)

          if self.class.instrument
            payload = { :key => key }
            payload.merge!(options) if options.is_a?(Hash)
            ActiveSupport::Notifications.instrument("cache_#{operation}.active_support", payload){ yield(payload) }
          else
            yield(nil)
          end
        end

        def log(operation, key, options = nil)
          return unless logger && logger.debug? && !silence?
          logger.debug("Cache #{operation}: #{key}#{options.blank? ? "" : " (#{options.inspect})"}")
        end

        def find_cached_entry(key, name, options)
          instrument(:read, name, options) do |payload|
            payload[:super_operation] = :fetch if payload
            read_entry(key, options)
          end
        end

        def handle_expired_entry(entry, key, options)
          if entry && entry.expired?
            race_ttl = options[:race_condition_ttl].to_i
            if (race_ttl > 0) && (Time.now.to_f - entry.expires_at <= race_ttl)
              # When an entry has :race_condition_ttl defined, put the stale entry back into the cache
              # for a brief period while the entry is begin recalculated.
              entry.expires_at = Time.now + race_ttl
              write_entry(key, entry, :expires_in => race_ttl * 2)
            else
              delete_entry(key, options)
            end
            entry = nil
          end
          entry
        end

        def get_entry_value(entry, name, options)
          instrument(:fetch_hit, name, options) { |payload| }
          entry.value
        end

        def save_block_result_to_cache(name, options)
          result = instrument(:generate, name, options) do |payload|
            yield(name)
          end

          write(name, result, options)
          result
        end
    end

    # This class is used to represent cache entries. Cache entries have a value and an optional
    # expiration time. The expiration time is used to support the :race_condition_ttl option
    # on the cache.
    #
    # Since cache entries in most instances will be serialized, the internals of this class are highly optimized
    # using short instance variable names that are lazily defined.
    class Entry # :nodoc:
      DEFAULT_COMPRESS_LIMIT = 16.kilobytes

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
        convert_version_4beta1_entry! if defined?(@v)
        compressed? ? uncompress(@value) : @value
      end

      # Check if the entry is expired. The +expires_in+ parameter can override
      # the value set when the entry was created.
      def expired?
        convert_version_4beta1_entry! if defined?(@v)
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
            @value.bytesize
          else
            @s = Marshal.dump(@value).bytesize
          end
        end
      end

      # Duplicate the value in a class. This is used by cache implementations that don't natively
      # serialize entries to protect against accidental cache modifications.
      def dup_value!
        convert_version_4beta1_entry! if defined?(@v)

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

        # The internals of this method changed between Rails 3.x and 4.0. This method provides the glue
        # to ensure that cache entries created under the old version still work with the new class definition.
        def convert_version_4beta1_entry!
          if defined?(@v)
            @value = @v
            remove_instance_variable(:@v)
          end

          if defined?(@c)
            @compressed = @c
            remove_instance_variable(:@c)
          end

          if defined?(@x) && @x
            @created_at ||= Time.now.to_f
            @expires_in = @x - @created_at
            remove_instance_variable(:@x)
          end
        end
    end
  end
end
