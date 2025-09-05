# frozen_string_literal: true

require 'monitor'

module ActiveSupport
  module Cache
    # = \Multi \Store
    #
    # A cache store implementation that allows you to stack other cache stores.
    class MultiStore < Store
      def initialize(*stores)
        options = stores.extract_options!

        # When no explicit options are provided and stores are pre-instantiated, inherit options
        # from the underlying stores. This ensures MultiStore uses the same default behaviors
        # (like expires_in, namespace, etc.) as the stores it wraps, avoiding the need for
        # users to redundantly specify the same options twice.
        # Options from earlier stores take precedence (L1 > L2 > L3, etc.) since L1 is the
        # primary cache and defines MultiStore's behavior.
        if options.empty?
          options = stores.reverse.each_with_object({}) do |store, merged|
            merged.merge!(store.options) if store.is_a?(ActiveSupport::Cache::Store)
          end
        end

        super(options)

        @monitor = Monitor.new
        @stores = stores.map do |store|
          if store.is_a?(ActiveSupport::Cache::Store)
            store
          elsif store.is_a?(Array)
            store_name, *store_args = store
            store_options = store_args.extract_options!
            merged_options = options.merge(store_options)
            ActiveSupport::Cache.lookup_store(store_name, *store_args, merged_options)
          else
            merged_options = options
            ActiveSupport::Cache.lookup_store(store, merged_options)
          end
        end
      end

      # Advertise cache versioning support.
      # Cache versioning is supported if all underlying stores support it.
      def supports_cache_versioning?
        @stores.all? { |store| store.class.supports_cache_versioning? }
      end

      protected

      def read_entry(key, **options)
        synchronize do
          @stores.each_with_index do |store, index|
            entry = store.send(:read_entry, key, **options)
            next unless entry

            promote_entry(key, entry, index, **options)
            return entry
          end
          nil
        end
      end

      def write_entry(key, entry, **options)
        synchronize do
          results = @stores.map { |store| store.send(:write_entry, key, entry.dup, **options) }
          results.all?
        end
      end

      def delete_entry(key, **options)
        synchronize do
          results = @stores.map { |store| store.send(:delete_entry, key, **options) }
          results.any?
        end
      end

      def write_multi_entries(entries, **options)
        synchronize do
          @stores.each do |store|
            store.send(:write_multi_entries, entries.transform_values(&:dup), **options)
          end
          true
        end
      end

      private

      def synchronize(&block)
        @monitor.synchronize(&block)
      end

      def promote_entry(key, entry, index, **options)
        return if index.zero? || entry.expired?

        @stores[0...index].each do |higher_store|
          higher_store.send(:write_entry, key, entry.dup, **options)
        end
      end

      def self.broadcast_to_stores(*methods)
        methods.each do |method|
          define_method(method) do |*args, **kwargs|
            synchronize do
              results = @stores.map do |store|
                store.public_send(method, *args, **kwargs)
              end
              # Return value depends on the method
              # For 'clear' and 'cleanup', return true
              # For 'increment' and 'decrement', return the result from the last store
              case method
              when :clear, :cleanup
                true
              when :increment, :decrement
                results.last
              else
                results
              end
            end
          end
        end
      end

      broadcast_to_stores :delete_matched, :increment, :decrement, :cleanup, :clear
    end
  end
end

