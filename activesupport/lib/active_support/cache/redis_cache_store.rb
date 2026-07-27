# frozen_string_literal: true

redis_client_min_version = "0.28.0"
begin
  gem "redis-client", ">= #{redis_client_min_version}"
rescue LoadError
  raise LoadError, <<~MSG
    The Redis cache store requires the redis-client gem version #{redis_client_min_version} or later.
    Please add it to your Gemfile:
      gem "redis-client", ">= #{redis_client_min_version}"
  MSG
end

require "redis-client"
require "active_support/deprecation"
require "active_support/core_ext/array/wrap"
require "active_support/core_ext/hash/slice"
require "active_support/core_ext/numeric/time"
require "active_support/digest"
require "active_support/inspect_backport"
require "active_support/core_ext/string/filters"

module ActiveSupport
  module Cache
    # = Redis \Cache \Store
    #
    # Deployment note: Take care to use a <b>dedicated Redis cache</b> rather
    # than pointing this at a persistent Redis server (for example, one used as
    # an Active Job queue). Redis won't cope well with mixed usage patterns and it
    # won't expire cache entries by default.
    #
    # Redis cache server setup guide: https://redis.io/topics/lru-cache
    #
    # * Supports vanilla Redis, hiredis, and +Redis::Distributed+.
    # * Supports Memcached-like sharding across Redises with +Redis::Distributed+.
    # * Fault tolerant. If the Redis server is unavailable, no exceptions are
    #   raised. Cache fetches are all misses and writes are dropped.
    # * Local cache. Hot in-memory primary cache within block/middleware scope.
    # * +read_multi+ and +write_multi+ support for Redis mget/mset. Use
    #   +Redis::Distributed+ 4.0.1+ for distributed mget support.
    # * +delete_matched+ support for Redis KEYS globs.
    # * +read+ supports <tt>delete: true</tt> to atomically read and delete
    #   a cache entry using the Redis +GETDEL+ command.
    #
    #     cache.write("greeting", "hello")
    #     cache.read("greeting", delete: true)  # => "hello"
    #     cache.read("greeting")                 # => nil
    #
    class RedisCacheStore < Store
      DEFAULT_REDIS_OPTIONS = ActiveSupport::Deprecation::DeprecatedObjectProxy.new(
        {
          connect_timeout: 1,
          read_timeout: 1,
          write_timeout: 1,
        }.freeze,
        "ActiveSupport::Cache::RedisCacheStore::DEFAULT_REDIS_OPTIONS is deprecated and will be removed in Rails 9.0. Pass timeout options to RedisCacheStore or a configured RedisClient instead.",
        ActiveSupport.deprecator,
      )

      DEFAULT_ERROR_HANDLER = -> (method:, returning:, exception:) do
        if logger
          logger.error { "RedisCacheStore: #{method} failed, returned #{returning.inspect}: #{exception.class}: #{exception.message}" }
        end
        ActiveSupport.error_reporter&.report(
          exception,
          severity: :warning,
          source: "redis_cache_store.active_support",
        )
      end

      # Advertise cache versioning support.
      def self.supports_cache_versioning?
        true
      end

      def self.new(**options)
        if options[:redis]
          ActiveSupport.deprecator.warn(<<~MSG.squish)
            Passing a Redis or ConnectionPool instance via the `:redis` configuration to ActiveSupport::Cache::RedisCacheStore
            is deprecated and will be removed in Rails 8.3.

            RedisCacheStore no longer depends on the `redis` gem, but use the simpler `redis-client`.

            Prefer passing a raw `:url` option instead, of if you need more advanced configuration, pass a configured `RedisClient`
            via the `:client` option.
          MSG
          return DeprecatedRedisCacheStore.new(**options)
        end

        super
      end

      prepend Strategy::LocalCache

      attr_reader :redis

      # Creates a new Redis cache store.
      #
      # The +:url+ param can be:
      #    - A string used to create a RedisClient::Pooled instance.
      #    - An array of strings used to create a +RedisClient::HashRing+ instance.
      #
      #   Option  Class       Result
      #   :url    String  ->  RedisClient.config(url: …).new_pool
      #   :url    Array   ->  RedisClient::HashRing.new([RedisClient.config(url: …).new_pool, ...])
      #
      # If you need some advanced configuration for the client, or want to use an alternative implementation
      # like `redis-cluster-client`, you can pass an already configured client via the +:client+ option:
      #
      #   config.cache_store = :redis_cache_store, client: RedisClient.config(...)
      #   config.cache_store = :redis_cache_store, client: [RedisClient.config(...), RedisClient.config(...)]
      #   config.cache_store = :redis_cache_store, client: -> { RedisClient.config(...) }
      #
      # No namespace is set by default. Provide one if the Redis cache
      # server is shared with other apps: <tt>namespace: 'myapp-cache'</tt>.
      #
      # Compression is enabled by default with a 1kB threshold, so cached
      # values larger than 1kB are automatically compressed. Disable by
      # passing <tt>compress: false</tt> or change the threshold by passing
      # <tt>compress_threshold: 4.kilobytes</tt>.
      #
      # No expiry is set on cache entries by default. Redis is expected to
      # be configured with an eviction policy that automatically deletes
      # least-recently or -frequently used keys when it reaches max memory.
      # See https://redis.io/topics/lru-cache for cache server setup.
      #
      # Race condition TTL is not set by default. This can be used to avoid
      # "thundering herd" cache writes when hot cache entries are expired.
      # See ActiveSupport::Cache::Store#fetch for more.
      #
      # Setting <tt>skip_nil: true</tt> will not cache nil results:
      #
      #   cache.fetch('foo') { nil }
      #   cache.fetch('bar', skip_nil: true) { nil }
      #   cache.exist?('foo') # => true
      #   cache.exist?('bar') # => false
      def initialize(error_handler: DEFAULT_ERROR_HANDLER, **redis_options)
        universal_options = redis_options.extract!(*UNIVERSAL_OPTIONS)
        pool_options = self.class.send(:retrieve_pool_options, redis_options)

        if redis_options.key?(:client)
          client = redis_options.delete(:client)
          clients = Array.wrap(client.respond_to?(:call) ? client.call : client)
        else
          urls = Array.wrap(redis_options.delete(:url))
          urls << nil if urls.empty?
          clients = urls.map do |url|
            RedisClient.config(url: url, protocol: 2, **redis_options)
          end
        end

        clients = clients.map do |c|
          if c.respond_to?(:new_pool)
            c.new_pool(**(pool_options || {}))
          else
            c
          end
        end

        @redis = if clients.size > 1
          RedisClient.ring(clients)
        else
          clients.first
        end

        @error_handler = error_handler

        super(universal_options)
      end

      ActiveSupport::InspectBackport.apply(self)

      # Cache Store API implementation.
      #
      # Read multiple values at once. Returns a hash of requested keys ->
      # fetched values.
      def read_multi(*names)
        return {} if names.empty?

        options = names.extract_options!
        options = merged_options(options)
        keys    = names.map { |name| normalize_key(name, options) }

        instrument_multi(:read_multi, keys, options) do |payload|
          read_multi_entries(names, **options).tap do |results|
            payload[:hits] = results.keys.map { |name| normalize_key(name, options) }
          end
        end
      end

      # The maximum number of entries to receive per SCAN call.
      SCAN_BATCH_SIZE = 1000
      private_constant :SCAN_BATCH_SIZE

      # Cache Store API implementation.
      #
      # Supports Redis KEYS glob patterns:
      #
      #   h?llo matches hello, hallo and hxllo
      #   h*llo matches hllo and heeeello
      #   h[ae]llo matches hello and hallo, but not hillo
      #   h[^e]llo matches hallo, hbllo, ... but not hello
      #   h[a-b]llo matches hallo and hbllo
      #
      # Use \ to escape special characters if you want to match them verbatim.
      #
      # See https://redis.io/commands/KEYS for more.
      #
      # Failsafe: Raises errors.
      def delete_matched(matcher, options = nil)
        unless String === matcher
          raise ArgumentError, "Only Redis glob strings are supported: #{matcher.inspect}"
        end
        pattern = namespace_key(matcher, options)

        instrument :delete_matched, pattern do
          redis.nodes.each do |node|
            node.with do |conn|
              conn.scan(match: pattern, count: SCAN_BATCH_SIZE).each_slice(SCAN_BATCH_SIZE).each do |keys|
                conn.call("unlink", *keys)
              end
            end
          end
        end
      end

      # Increment a cached integer value using the Redis incrby atomic operator.
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
      #
      # To read the value later, call #read_counter:
      #
      #   cache.increment("baz") # => 7
      #   cache.read_counter("baz") # 7
      #
      # Failsafe: Raises errors.
      def increment(name, amount = 1, options = nil)
        options = merged_options(options)
        key = normalize_key(name, options)

        instrument :increment, key, amount: amount do
          failsafe :increment do
            change_counter(key, amount, options)
          end
        end
      end

      # Decrement a cached integer value using the Redis decrby atomic operator.
      # Returns the updated value.
      #
      # If the key is unset or has expired, it will be set to +-amount+:
      #
      #   cache.decrement("foo") # => -1
      #
      # To set a specific value, call #write passing <tt>raw: true</tt>:
      #
      #   cache.write("baz", 5, raw: true)
      #   cache.decrement("baz") # => 4
      #
      # Decrementing a non-numeric value, or a value written without
      # <tt>raw: true</tt>, will fail and return +nil+.
      #
      # To read the value later, call #read_counter:
      #
      #   cache.decrement("baz") # => 3
      #   cache.read_counter("baz") # 3
      #
      # Failsafe: Raises errors.
      def decrement(name, amount = 1, options = nil)
        options = merged_options(options)
        key = normalize_key(name, options)

        instrument :decrement, key, amount: amount do
          failsafe :decrement do
            change_counter(key, -amount, options)
          end
        end
      end

      # Cache Store API implementation.
      #
      # Removes expired entries. Handled natively by Redis least-recently-/
      # least-frequently-used expiry, so manual cleanup is not supported.
      def cleanup(options = nil)
        super
      end

      # Clear the entire cache on all Redis servers. Safe to use on
      # shared servers if the cache is namespaced.
      #
      # Failsafe: Raises errors.
      def clear(options = nil)
        failsafe :clear do
          if namespace = merged_options(options)[:namespace]
            delete_matched "*", namespace: namespace
          else
            redis.then { |c| c.flushdb }
          end
        end
      end

      # Get info from redis servers.
      def stats
        redis.then { |c| c.info }
      end

      private
        def instance_variables_to_inspect
          [:@options, :@redis].freeze
        end

        # Store provider interface:
        # Read an entry from the cache.
        def read_entry(key, **options)
          deserialize_entry(read_serialized_entry(key, **options), **options)
        end

        def read_serialized_entry(key, raw: false, **options)
          failsafe :read_entry do
            command = options[:delete] ? "getdel" : "get"
            redis.node_for(key).call(command, key)
          end
        end

        def read_multi_entries(names, **options)
          options = merged_options(options)
          return {} if names == []
          raw = options&.fetch(:raw, false)

          keys = names.map { |name| normalize_key(name, options) }
          keys_index = keys.each_with_index.to_h

          results = {}

          redis.nodes_for(keys).each do |node, key_subset|
            failsafe(:read_multi_entries) do
              node.call("mget", *key_subset).each_with_index do |value, index|
                if value
                  results[names[keys_index[key_subset[index]]]] = value
                end
              end
            end
          end

          results.transform_values! { |value| deserialize_entry(value, raw: raw) }
          results.reject! do |name, entry|
            entry.nil? || entry.expired? || entry.mismatched?(normalize_version(name, options))
          end
          results.compact!
          results.transform_values! { |entry| entry&.value }
          results
        end

        # Write an entry to the cache.
        #
        # Requires Redis 2.6.12+ for extended SET options.
        def write_entry(key, entry, raw: false, **options)
          write_serialized_entry(key, serialize_entry(entry, raw: raw, **options), raw: raw, **options)
        end

        def write_serialized_entry(key, payload, raw: false, unless_exist: false, expires_in: nil, race_condition_ttl: nil, pipeline: nil, **options)
          # If race condition TTL is in use, ensure that cache entries
          # stick around a bit longer after they would have expired
          # so we can purposefully serve stale entries.
          if race_condition_ttl && expires_in && expires_in > 0 && !raw
            expires_in += 5.minutes
          end

          modifiers = []
          if unless_exist || expires_in
            modifiers << :nx if unless_exist
            modifiers << :px << (1000 * expires_in.to_f).ceil if expires_in
          end

          if pipeline
            pipeline.call("set", key, payload, *modifiers)
          else
            failsafe :write_entry, returning: nil do
              redis.node_for(key).call("set", key, payload, *modifiers) == "OK"
            end
          end
        end

        # Delete an entry from the cache.
        def delete_entry(key, **options)
          failsafe :delete_entry, returning: false do
            redis.node_for(key).call("unlink", key) == 1
          end
        end

        # Deletes multiple entries in the cache. Returns the number of entries deleted.
        def delete_multi_entries(entries, **_options)
          return 0 if entries.empty?

          count = 0
          redis.nodes_for(*entries).each do |node, keys|
            failsafe :delete_multi_entries do
              count += node.call("unlink", *keys)
            end
          end

          count
        end

        # Nonstandard store provider API to write multiple values at once.
        def write_multi_entries(entries, **options)
          return if entries.empty?

          redis.nodes_for(entries.keys).each do |node, keys|
            failsafe :write_multi_entries do
              node.pipelined do |pipeline|
                entries.slice(*keys).each do |key, entry|
                  write_entry key, entry, **options, pipeline: pipeline
                end
              end
            end
          end
        end

        def deserialize_entry(payload, raw: false, **)
          if raw && !payload.nil?
            Entry.new(payload)
          else
            super(payload)
          end
        end

        def serialize_entry(entry, raw: false, **options)
          if raw
            entry.value.to_s
          else
            super(entry, raw: raw, **options)
          end
        end

        def change_counter(key, amount, options)
          redis.node_for(key).with do |c|
            expires_in = options[:expires_in]

            if expires_in
              if supports_expire_nx?
                count, _ = c.pipelined do |pipeline|
                  pipeline.call("incrby", key, amount)
                  pipeline.call("expire", key, expires_in.to_i, "NX")
                end
              else
                count, ttl = c.pipelined do |pipeline|
                  pipeline.call("incrby", key, amount)
                  pipeline.call("ttl", key)
                end
                c.call("expire", key, expires_in.to_i) if ttl < 0
              end
            else
              count = c.call("incrby", key, amount)
            end

            count
          end
        end

        def supports_expire_nx?
          return @supports_expire_nx if defined?(@supports_expire_nx)

          redis_versions = redis.nodes.map { |n| n.call("info", "server").scan(/edis_version:([\d.]+)/)[0][0] || "0" }
          @supports_expire_nx = redis_versions.all? { |v| Gem::Version.new(v) >= Gem::Version.new("7.0.0") }
        end

        def failsafe(method, returning: nil)
          yield
        rescue ::RedisClient::ConnectionError => error
          @error_handler&.call(method: method, exception: error, returning: returning)
          returning
        end
    end
  end
end
