# frozen_string_literal: true

require "monitor"

module ActiveSupport
  module Cache
    # = Memory \Cache \Store
    #
    # A cache store implementation which stores everything into memory in the
    # same process. If you're running multiple Ruby on \Rails server processes
    # (which is the case if you're using Phusion Passenger or puma clustered mode),
    # then this means that \Rails server process instances won't be able
    # to share cache data with each other and this may not be the most
    # appropriate cache in that scenario.
    #
    # This cache has a bounded size specified by the +:size+ options to the
    # initializer (default is 32Mb). When the cache exceeds the allotted size,
    # a cleanup will occur which tries to prune the cache down to three quarters
    # of the maximum size by removing the least recently used entries.
    #
    # Unlike other Cache store implementations, +MemoryStore+ does not compress
    # values by default. +MemoryStore+ does not benefit from compression as much
    # as other Store implementations, as it does not send data over a network.
    # However, when compression is enabled, it still pays the full cost of
    # compression in terms of cpu use.
    #
    # +MemoryStore+ is thread-safe.
    class MemoryStore < Store
      module DupCoder # :nodoc:
        extend self

        def dump(entry)
          if entry.value && entry.value != true && !entry.value.is_a?(Numeric)
            Cache::Entry.new(dump_value(entry.value), expires_at: entry.expires_at, version: entry.version)
          else
            entry
          end
        end

        def dump_compressed(entry, threshold)
          compressed_entry = entry.compressed(threshold)
          compressed_entry.compressed? ? compressed_entry : dump(entry)
        end

        def load(entry)
          if !entry.compressed? && entry.value.is_a?(String)
            Cache::Entry.new(load_value(entry.value), expires_at: entry.expires_at, version: entry.version)
          else
            entry
          end
        end

        private
          MARSHAL_SIGNATURE = "\x04\x08".b.freeze

          def dump_value(value)
            if value.is_a?(String) && !value.start_with?(MARSHAL_SIGNATURE)
              value.dup
            else
              Marshal.dump(value)
            end
          end

          def load_value(string)
            if string.start_with?(MARSHAL_SIGNATURE)
              Marshal.load(string)
            else
              string.dup
            end
          end
      end

      def initialize(options = nil)
        options ||= {}
        options[:coder] = DupCoder unless options.key?(:coder) || options.key?(:serializer)
        # Disable compression by default.
        options[:compress] ||= false
        super(options)
        @data = {}
        @max_size = options[:size] || 32.megabytes
        @max_prune_time = options[:max_prune_time] || 2
        @cache_size = 0
        @monitor = Monitor.new
        @pruning = false
      end

      # Advertise cache versioning support.
      def self.supports_cache_versioning?
        true
      end

      # Delete all data stored in a given cache store.
      def clear(options = nil)
        synchronize do
          @data.clear
          @cache_size = 0
        end
      end

      # Preemptively iterates through all stored keys and removes the ones which have expired.
      def cleanup(options = nil)
        options = merged_options(options)
        _instrument(:cleanup, size: @data.size) do
          keys = synchronize { @data.keys }
          keys.each do |key|
            entry = @data[key]
            delete_entry(key, **options) if entry && entry.expired?
          end
        end
      end

      # To ensure entries fit within the specified memory prune the cache by removing the least
      # recently accessed entries.
      def prune(target_size, max_time = nil)
        return if pruning?
        @pruning = true
        begin
          start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          cleanup
          instrument(:prune, target_size, from: @cache_size) do
            keys = synchronize { @data.keys }
            keys.each do |key|
              delete_entry(key, **options)
              return if @cache_size <= target_size || (max_time && Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time > max_time)
            end
          end
        ensure
          @pruning = false
        end
      end

      # Returns true if the cache is currently being pruned.
      def pruning?
        @pruning
      end

      # Increment a cached integer value. Returns the updated value.
      #
      # If the key is unset, it will be set to +amount+:
      #
      #   cache.increment("foo") # => 1
      #   cache.increment("bar", 100) # => 100
      #
      # To set a specific value, call #write:
      #
      #   cache.write("baz", 5)
      #   cache.increment("baz") # => 6
      #
      def increment(name, amount = 1, options = nil)
        instrument(:increment, name, amount: amount) do
          modify_value(name, amount, options)
        end
      end

      # Decrement a cached integer value. Returns the updated value.
      #
      # If the key is unset or has expired, it will be set to +-amount+.
      #
      #   cache.decrement("foo") # => -1
      #
      # To set a specific value, call #write:
      #
      #   cache.write("baz", 5)
      #   cache.decrement("baz") # => 4
      #
      def decrement(name, amount = 1, options = nil)
        instrument(:decrement, name, amount: amount) do
          modify_value(name, -amount, options)
        end
      end

      # Deletes cache entries if the cache key matches a given pattern.
      def delete_matched(matcher, options = nil)
        options = merged_options(options)
        matcher = key_matcher(matcher, options)

        instrument(:delete_matched, matcher.inspect) do
          keys = synchronize { @data.keys }
          keys.each do |key|
            delete_entry(key, **options) if key.match(matcher)
          end
        end
      end

      def inspect # :nodoc:
        "#<#{self.class.name} entries=#{@data.size}, size=#{@cache_size}, options=#{@options.inspect}>"
      end

      # Synchronize calls to the cache. This should be called wherever the underlying cache implementation
      # is not thread safe.
      def synchronize(&block) # :nodoc:
        @monitor.synchronize(&block)
      end

      private
        PER_ENTRY_OVERHEAD = 240

        def cached_size(key, payload)
          key.to_s.bytesize + payload.bytesize + PER_ENTRY_OVERHEAD
        end

        def read_entry(key, **options)
          entry = nil
          synchronize do
            payload = @data.delete(key)
            if payload
              @data[key] = payload
              entry = deserialize_entry(payload)
            end
          end
          entry
        end

        def write_entry(key, entry, **options)
          payload = serialize_entry(entry, **options)
          synchronize do
            return false if options[:unless_exist] && exist?(key, namespace: nil)

            old_payload = @data[key]
            if old_payload
              @cache_size -= (old_payload.bytesize - payload.bytesize)
            else
              @cache_size += cached_size(key, payload)
            end
            @data[key] = payload
            prune(@max_size * 0.75, @max_prune_time) if @cache_size > @max_size
            true
          end
        end

        def delete_entry(key, **options)
          synchronize do
            payload = @data.delete(key)
            @cache_size -= cached_size(key, payload) if payload
            !!payload
          end
        end

        # Modifies the amount of an integer value that is stored in the cache.
        # If the key is not found it is created and set to +amount+.
        def modify_value(name, amount, options)
          options = merged_options(options)
          key     = normalize_key(name, options)
          version = normalize_version(name, options)

          synchronize do
            entry = read_entry(key, **options)

            if !entry || entry.expired? || entry.mismatched?(version)
              write(name, Integer(amount), options)
              amount
            else
              num = entry.value.to_i + amount
              entry = Entry.new(num, expires_at: entry.expires_at, version: entry.version)
              write_entry(key, entry)
              num
            end
          end
        end
    end
  end
end
