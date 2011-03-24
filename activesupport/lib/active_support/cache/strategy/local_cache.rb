require 'active_support/core_ext/object/duplicable'
require 'active_support/core_ext/string/inflections'

module ActiveSupport
  module Cache
    module Strategy
      # Caches that implement LocalCache will be backed by an in memory cache for the
      # duration of a block. Repeated calls to the cache for the same key will hit the
      # in memory cache for faster access.
      module LocalCache
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

          def read_entry(key, options)
            @data[key]
          end

          def write_entry(key, value, options)
            @data[key] = value
            true
          end

          def delete_entry(key, options)
            !!@data.delete(key)
          end
        end

        # Use a local cache for the duration of block.
        def with_local_cache
          save_val = Thread.current[thread_local_key]
          begin
            Thread.current[thread_local_key] = LocalStore.new
            yield
          ensure
            Thread.current[thread_local_key] = save_val
          end
        end

        #--
        # This class wraps up local storage for middlewares. Only the middleware method should
        # construct them.
        class Middleware # :nodoc:
          attr_reader :name, :thread_local_key

          def initialize(name, thread_local_key)
            @name             = name
            @thread_local_key = thread_local_key
            @app              = nil
          end

          def new(app)
            @app = app
            self
          end

          def call(env)
            Thread.current[thread_local_key] = LocalStore.new
            @app.call(env)
          ensure
            Thread.current[thread_local_key] = nil
          end
        end

        # Middleware class can be inserted as a Rack handler to be local cache for the
        # duration of request.
        def middleware
          @middleware ||= Middleware.new(
            "ActiveSupport::Cache::Strategy::LocalCache",
            thread_local_key)
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
          if local_cache
            local_cache.mute do
              if value
                local_cache.write(name, value, options)
              else
                local_cache.delete(name, options)
              end
            end
          end
          value
        end

        def decrement(name, amount = 1, options = nil) # :nodoc:
          value = bypass_local_cache{super}
          if local_cache
            local_cache.mute do
              if value
                local_cache.write(name, value, options)
              else
                local_cache.delete(name, options)
              end
            end
          end
          value
        end

        protected
          def read_entry(key, options) # :nodoc:
            if local_cache
              entry = local_cache.read_entry(key, options)
              unless entry
                entry = super
                local_cache.write_entry(key, entry, options)
              end
              entry
            else
              super
            end
          end

          def write_entry(key, entry, options) # :nodoc:
            local_cache.write_entry(key, entry, options) if local_cache
            super
          end

          def delete_entry(key, options) # :nodoc:
            local_cache.delete_entry(key, options) if local_cache
            super
          end

        private
          def thread_local_key
            @thread_local_key ||= "#{self.class.name.underscore}_local_cache_#{object_id}".gsub(/[\/-]/, '_').to_sym
          end

          def local_cache
            Thread.current[thread_local_key]
          end

          def bypass_local_cache
            save_cache = Thread.current[thread_local_key]
            begin
              Thread.current[thread_local_key] = nil
              yield
            ensure
              Thread.current[thread_local_key] = save_cache
            end
          end
      end
    end
  end
end
