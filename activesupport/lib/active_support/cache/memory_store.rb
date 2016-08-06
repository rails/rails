require "monitor"

module ActiveSupport
  module Cache
    # A cache store implementation which stores everything into memory in the
    # same process. If you're running multiple Ruby on Rails server processes
    # (which is the case if you're using mongrel_cluster or Phusion Passenger),
    # then this means that Rails server process instances won't be able
    # to share cache data with each other and this may not be the most
    # appropriate cache in that scenario.
    #
    # This cache has a bounded size specified by the :size options to the
    # initializer (default is 32Mb). When the cache exceeds the allotted size,
    # a cleanup will occur which tries to prune the cache down to three quarters
    # of the maximum size by removing the least recently used entries.
    #
    # MemoryStore is thread-safe.
    class MemoryStore < Store
      def initialize(options = nil)
        options ||= {}
        super(options)
        @data = {}
        @key_access = {}
        @max_size = options[:size] || 32.megabytes
        @max_prune_time = options[:max_prune_time] || 2
        @cache_size = 0
        @monitor = Monitor.new
        @pruning = false
      end

      def clear(options = nil)
        synchronize do
          @data.clear
          @key_access.clear
          @cache_size = 0
        end
      end

      # Preemptively iterates through all stored keys and removes the ones which have expired.
      def cleanup(options = nil)
        options = merged_options(options)
        instrument(:cleanup, size: @data.size) do
          keys = synchronize{ @data.keys }
          keys.each do |key|
            entry = @data[key]
            delete_entry(key, options) if entry && entry.expired?
          end
        end
      end

      # To ensure entries fit within the specified memory prune the cache by removing the least
      # recently accessed entries.
      def prune(target_size, max_time = nil)
        return if pruning?
        @pruning = true
        begin
          start_time = Time.now
          cleanup
          instrument(:prune, target_size, from: @cache_size) do
            keys = synchronize{ @key_access.keys.sort{|a,b| @key_access[a].to_f <=> @key_access[b].to_f} }
            keys.each do |key|
              delete_entry(key, options)
              return if @cache_size <= target_size || (max_time && Time.now - start_time > max_time)
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

      # Increment an integer value in the cache.
      def increment(name, amount = 1, options = nil)
        modify_value(name, amount, options)
      end

      # Decrement an integer value in the cache.
      def decrement(name, amount = 1, options = nil)
        modify_value(name, -amount, options)
      end

      def delete_matched(matcher, options = nil)
        options = merged_options(options)
        instrument(:delete_matched, matcher.inspect) do
          matcher = key_matcher(matcher, options)
          keys = synchronize { @data.keys }
          keys.each do |key|
            delete_entry(key, options) if key.match(matcher)
          end
        end
      end

      def inspect # :nodoc:
        "<##{self.class.name} entries=#{@data.size}, size=#{@cache_size}, options=#{@options.inspect}>"
      end

      # Synchronize calls to the cache. This should be called wherever the underlying cache implementation
      # is not thread safe.
      def synchronize(&block) # :nodoc:
        @monitor.synchronize(&block)
      end

      protected

        PER_ENTRY_OVERHEAD = 240

        def cached_size(key, entry) # :nodoc:
          key.to_s.bytesize + entry.size + PER_ENTRY_OVERHEAD
        end

        def read_entry(key, options) # :nodoc:
          entry = @data[key]
          synchronize do
            if entry
              @key_access[key] = Time.now.to_f
            else
              @key_access.delete(key)
            end
          end
          entry
        end

        def write_entry(key, entry, options) # :nodoc:
          entry.dup_value!
          synchronize do
            old_entry = @data[key]
            return false if @data.key?(key) && options[:unless_exist]
            if old_entry
              @cache_size -= (old_entry.size - entry.size)
            else
              @cache_size += cached_size(key, entry)
            end
            @key_access[key] = Time.now.to_f
            @data[key] = entry
            prune(@max_size * 0.75, @max_prune_time) if @cache_size > @max_size
            true
          end
        end

        def delete_entry(key, options) # :nodoc:
          synchronize do
            @key_access.delete(key)
            entry = @data.delete(key)
            @cache_size -= cached_size(key, entry) if entry
            !!entry
          end
        end

      private

        def modify_value(name, amount, options)
          synchronize do
            options = merged_options(options)
            if num = read(name, options)
              num = num.to_i + amount
              write(name, num, options)
              num
            end
          end
        end
    end
  end
end
