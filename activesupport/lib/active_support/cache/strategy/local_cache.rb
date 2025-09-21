# frozen_string_literal: true

require "active_support/core_ext/string/inflections"

module ActiveSupport
  module Cache
    module Strategy
      # = Local \Cache \Strategy
      #
      # Caches that implement LocalCache will be backed by an in-memory cache for the
      # duration of a block. Repeated calls to the cache for the same key will hit the
      # in-memory cache for faster access.
      module LocalCache
        autoload :Middleware, "active_support/cache/strategy/local_cache_middleware"

        # Class for storing and registering the local caches.
        module LocalCacheRegistry # :nodoc:
          extend self

          def cache_for(local_cache_key)
            registry = ActiveSupport::IsolatedExecutionState[:active_support_local_cache_registry] ||= {}
            registry[local_cache_key]
          end

          def set_cache_for(local_cache_key, value)
            registry = ActiveSupport::IsolatedExecutionState[:active_support_local_cache_registry] ||= {}
            registry[local_cache_key] = value
          end
        end

        # = Local \Cache \Store
        #
        # Simple memory backed cache. This cache is not thread safe and is intended only
        # for serving as a temporary memory cache for a single thread.
        class LocalStore
          def initialize
            @data = {}
          end

          def clear(options = nil)
            @data.clear
          end

          def read_entry(key)
            @data[key]
          end

          def read_multi_entries(keys)
            @data.slice(*keys)
          end

          def write_entry(key, entry)
            @data[key] = entry
            true
          end

          def delete_entry(key)
            !!@data.delete(key)
          end

          def fetch_entry(key) # :nodoc:
            @data.fetch(key) { @data[key] = yield }
          end
        end

        # Use a local cache for the duration of block.
        def with_local_cache(&block)
          use_temporary_local_cache(LocalStore.new, &block)
        end

        # Set a new local cache.
        def new_local_cache
          LocalCacheRegistry.set_cache_for(local_cache_key, LocalStore.new)
        end

        # Unset the current local cache.
        def unset_local_cache
          LocalCacheRegistry.set_cache_for(local_cache_key, nil)
        end

        # The current local cache.
        def local_cache
          LocalCacheRegistry.cache_for(local_cache_key)
        end

        # Middleware class can be inserted as a Rack handler to be local cache for the
        # duration of request.
        def middleware
          @middleware ||= Middleware.new("ActiveSupport::Cache::Strategy::LocalCache", self)
        end

        def clear(options = nil) # :nodoc:
          return super unless cache = local_cache
          cache.clear(options)
          super
        end

        def cleanup(options = nil) # :nodoc:
          return super unless cache = local_cache
          cache.clear(options)
          super
        end

        def delete_matched(matcher, options = nil) # :nodoc:
          return super unless cache = local_cache
          cache.clear(options)
          super
        end

        def increment(name, amount = 1, **options) # :nodoc:
          return super unless local_cache
          value = bypass_local_cache { super }
          write_cache_value(name, value, raw: true, **options)
          value
        end

        def decrement(name, amount = 1, **options) # :nodoc:
          return super unless local_cache
          value = bypass_local_cache { super }
          write_cache_value(name, value, raw: true, **options)
          value
        end

        def fetch_multi(*names, &block) # :nodoc:
          return super if local_cache.nil? || names.empty?

          options = names.extract_options!
          options = merged_options(options)

          keys_to_names = names.index_by { |name| normalize_key(name, options) }

          local_entries = local_cache.read_multi_entries(keys_to_names.keys)
          results = local_entries.each_with_object({}) do |(key, value), result|
            # If we recorded a miss in the local cache, `#fetch_multi` will forward
            # that key to the real store, and the entry will be replaced
            # local_cache.delete_entry(key)
            next if value.nil?

            entry = deserialize_entry(value, **options)

            normalized_key = keys_to_names[key]
            if entry.nil?
              result[normalized_key] = nil
            elsif entry.expired? || entry.mismatched?(normalize_version(normalized_key, options))
              local_cache.delete_entry(key)
            else
              result[normalized_key] = entry.value
            end
          end

          if results.size < names.size
            results.merge!(super(*(names - results.keys), options, &block))
          end

          results
        end

        private
          def read_serialized_entry(key, raw: false, **options)
            if cache = local_cache
              hit = true
              entry = cache.fetch_entry(key) do
                hit = false
                super
              end
              options[:event][:store] = cache.class.name if hit && options[:event]
              entry
            else
              super
            end
          end

          def read_multi_entries(names, **options)
            return super unless local_cache

            keys_to_names = names.index_by { |name| normalize_key(name, options) }

            local_entries = local_cache.read_multi_entries(keys_to_names.keys)

            results = local_entries.each_with_object({}) do |(key, value), result|
              next if value.nil? # recorded cache miss

              entry = deserialize_entry(value, **options)

              normalized_key = keys_to_names[key]
              if entry.nil?
                result[normalized_key] = nil
              elsif entry.expired? || entry.mismatched?(normalize_version(normalized_key, options))
                local_cache.delete_entry(key)
              else
                result[normalized_key] = entry.value
              end
            end

            if results.size < names.size
              results.merge!(super(names - results.keys, **options))
            end

            results
          end

          def write_serialized_entry(key, payload, **)
            if return_value = super
              local_cache.write_entry(key, payload) if local_cache
            else
              local_cache.delete_entry(key) if local_cache
            end
            return_value
          end

          def delete_entry(key, **)
            local_cache.delete_entry(key) if local_cache
            super
          end

          def write_cache_value(name, value, **options)
            name = normalize_key(name, options)
            cache = local_cache
            if value
              cache.write_entry(name, serialize_entry(new_entry(value, **options), **options))
            else
              cache.delete_entry(name)
            end
          end

          def local_cache_key
            @local_cache_key ||= "#{self.class.name.underscore}_local_cache_#{object_id}".gsub(/[\/-]/, "_").to_sym
          end

          def bypass_local_cache(&block)
            use_temporary_local_cache(nil, &block)
          end

          def use_temporary_local_cache(temporary_cache)
            save_cache = LocalCacheRegistry.cache_for(local_cache_key)
            begin
              LocalCacheRegistry.set_cache_for(local_cache_key, temporary_cache)
              yield
            ensure
              LocalCacheRegistry.set_cache_for(local_cache_key, save_cache)
            end
          end
      end
    end
  end
end
