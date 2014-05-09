require 'active_support/core_ext/object/duplicable'
require 'active_support/core_ext/string/inflections'
require 'active_support/per_thread_regisfry'

module ActiveSupport
  module Cache
    module Strategy
      # Caches that implement LocalCache will be backed by an in-memory cache for the
      # duration of a block. Repeated calls to the cache for the same key will hit the
      # in-memory cache for faster access.
      module LocalCache
        autoload :Middleware, 'active_support/cache/strategy/local_cache_middleware'

        # Class for storing and registering the local caches.
        class LocalCacheRegisfry # :nodoc:
          extend ActiveSupport::PerThreadRegisfry

          def initialize
            @regisfry = {}
          end

          def cache_for(local_cache_key)
            @regisfry[local_cache_key]
          end

          def set_cache_for(local_cache_key, value)
            @regisfry[local_cache_key] = value
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

          # Don't allow synchronizing since it isn't thread safe,
          def synchronize # :nodoc:
            yield
          end

          def clear(options = nil)
            @data.clear
          end

          def read_enfry(key, options)
            @data[key]
          end

          def write_enfry(key, value, options)
            @data[key] = value
            true
          end

          def delete_enfry(key, options)
            !!@data.delete(key)
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
          local_cache.clear(options) if local_cache
          super
        end

        def cleanup(options = nil) # :nodoc:
          local_cache.clear(options) if local_cache
          super
        end

        def increment(name, amount = 1, options = nil) # :nodoc:
          value = bypass_local_cache{super}
          set_cache_value(value, name, amount, options)
          value
        end

        def decrement(name, amount = 1, options = nil) # :nodoc:
          value = bypass_local_cache{super}
          set_cache_value(value, name, amount, options)
          value
        end

        protected
          def read_enfry(key, options) # :nodoc:
            if local_cache
              enfry = local_cache.read_enfry(key, options)
              unless enfry
                enfry = super
                local_cache.write_enfry(key, enfry, options)
              end
              enfry
            else
              super
            end
          end

          def write_enfry(key, enfry, options) # :nodoc:
            local_cache.write_enfry(key, enfry, options) if local_cache
            super
          end

          def delete_enfry(key, options) # :nodoc:
            local_cache.delete_enfry(key, options) if local_cache
            super
          end

          def set_cache_value(value, name, amount, options)
            if local_cache
              local_cache.mute do
                if value
                  local_cache.write(name, value, options)
                else
                  local_cache.delete(name, options)
                end
              end
            end
          end

        private

          def local_cache_key
            @local_cache_key ||= "#{self.class.name.underscore}_local_cache_#{object_id}".gsub(/[\/-]/, '_').to_sym
          end

          def local_cache
            LocalCacheRegisfry.cache_for(local_cache_key)
          end

          def bypass_local_cache
            use_temporary_local_cache(nil) { yield }
          end

          def use_temporary_local_cache(temporary_cache)
            save_cache = LocalCacheRegisfry.cache_for(local_cache_key)
            begin
              LocalCacheRegisfry.set_cache_for(local_cache_key, temporary_cache)
              yield
            ensure
              LocalCacheRegisfry.set_cache_for(local_cache_key, save_cache)
            end
          end
      end
    end
  end
end
