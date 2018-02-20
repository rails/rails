# frozen_string_literal: true

require "active_support/core_ext/object/duplicable"
require "active_support/core_ext/string/inflections"
require "active_support/per_thread_registry"

module ActiveSupport
  module Cache
    module Strategy
      # Caches that implement LocalCache will be backed by an in-memory cache for the
      # duration of a block. Repeated calls to the cache for the same key will hit the
      # in-memory cache for faster access.
      module LocalCache
        autoload :Middleware, "active_support/cache/strategy/local_cache_middleware"

        # Class for storing and registering the local caches.
        class LocalCacheRegistry # :nodoc:
          extend ActiveSupport::PerThreadRegistry

          def initialize
            @registry = {}
          end

          def cache_for(local_cache_key)
            @registry[local_cache_key]
          end

          def set_cache_for(local_cache_key, value)
            @registry[local_cache_key] = value
          end

          def self.set_cache_for(l, v); instance.set_cache_for l, v; end
          def self.cache_for(l); instance.cache_for l; end
        end

        # Simple memory backed cache. This cache is not thread safe and is intended only
        # for serving as a temporary memory cache for a single thread.
        class LocalStore < Store
          def initialize
            super
            @data = {}
          end

          # Don't allow synchronizing since it isn't thread safe.
          def synchronize # :nodoc:
            yield
          end

          def clear(options = nil)
            @data.clear
          end

          def read_entry(key, options)
            @data[key]
          end

          def read_multi_entries(keys, options)
            Hash[keys.map { |name| [name, read_entry(name, options)] }.keep_if { |_name, value| value }]
          end

          def write_entry(key, value, options)
            @data[key] = value
            true
          end

          def delete_entry(key, options)
            !!@data.delete(key)
          end

          def fetch_entry(key, options = nil) # :nodoc:
            @data.fetch(key) { @data[key] = yield }
          end
        end

        # Use a local cache for the duration of block.
        def with_local_cache
          use_temporary_local_cache(LocalStore.new) { yield }
        end

        # Middleware class can be inserted as a Rack handler to be local cache for the
        # duration of request.
        def middleware
          @middleware ||= Middleware.new(
            "ActiveSupport::Cache::Strategy::LocalCache",
            local_cache_key)
        end

        def clear(options = nil) # :nodoc:
          return super unless cache = local_cache
          cache.clear(options)
          super
        end

        def cleanup(options = nil) # :nodoc:
          return super unless cache = local_cache
          cache.clear
          super
        end

        def increment(name, amount = 1, options = nil) # :nodoc:
          return super unless local_cache
          value = bypass_local_cache { super }
          write_cache_value(name, value, options)
          value
        end

        def decrement(name, amount = 1, options = nil) # :nodoc:
          return super unless local_cache
          value = bypass_local_cache { super }
          write_cache_value(name, value, options)
          value
        end

        private
          def read_entry(key, options)
            if cache = local_cache
              cache.fetch_entry(key) { super }
            else
              super
            end
          end

          def read_multi_entries(keys, options)
            return super unless local_cache

            local_entries = local_cache.read_multi_entries(keys, options)
            missed_keys = keys - local_entries.keys

            if missed_keys.any?
              local_entries.merge!(super(missed_keys, options))
            else
              local_entries
            end
          end

          def write_entry(key, entry, options)
            if options[:unless_exist]
              local_cache.delete_entry(key, options) if local_cache
            else
              local_cache.write_entry(key, entry, options) if local_cache
            end

            super
          end

          def delete_entry(key, options)
            local_cache.delete_entry(key, options) if local_cache
            super
          end

          def write_cache_value(name, value, options)
            name = normalize_key(name, options)
            cache = local_cache
            cache.mute do
              if value
                cache.write(name, value, options)
              else
                cache.delete(name, options)
              end
            end
          end

          def local_cache_key
            @local_cache_key ||= "#{self.class.name.underscore}_local_cache_#{object_id}".gsub(/[\/-]/, "_").to_sym
          end

          def local_cache
            LocalCacheRegistry.cache_for(local_cache_key)
          end

          def bypass_local_cache
            use_temporary_local_cache(nil) { yield }
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
