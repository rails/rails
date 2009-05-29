require 'active_support/core_ext/object/duplicable'

module ActiveSupport
  module Cache
    module Strategy
      module LocalCache
        # this allows caching of the fact that there is nothing in the remote cache
        NULL = 'remote_cache_store:null'

        def with_local_cache
          Thread.current[thread_local_key] = MemoryStore.new
          yield
        ensure
          Thread.current[thread_local_key] = nil
        end

        def middleware
          @middleware ||= begin
            klass = Class.new
            klass.class_eval(<<-EOS, __FILE__, __LINE__)
              def initialize(app)
                @app = app
              end

              def call(env)
                Thread.current[:#{thread_local_key}] = MemoryStore.new
                @app.call(env)
              ensure
                Thread.current[:#{thread_local_key}] = nil
              end
            EOS

            def klass.to_s
              "ActiveSupport::Cache::Strategy::LocalCache"
            end

            klass
          end
        end

        def read(key, options = nil)
          value = local_cache && local_cache.read(key)
          if value == NULL
            nil
          elsif value.nil?
            value = super
            local_cache.write(key, value || NULL) if local_cache
            value.duplicable? ? value.dup : value
          else
            # forcing the value to be immutable
            value.duplicable? ? value.dup : value
          end
        end

        def write(key, value, options = nil)
          value = value.to_s if respond_to?(:raw?) && raw?(options)
          local_cache.write(key, value || NULL) if local_cache
          super
        end

        def delete(key, options = nil)
          local_cache.write(key, NULL) if local_cache
          super
        end

        def exist(key, options = nil)
          value = local_cache.read(key) if local_cache
          if value == NULL
            false
          elsif value
            true
          else
            super
          end
        end

        def increment(key, amount = 1)
          if value = super
            local_cache.write(key, value.to_s) if local_cache
            value
          else
            nil
          end
        end

        def decrement(key, amount = 1)
          if value = super
            local_cache.write(key, value.to_s) if local_cache
            value
          else
            nil
          end
        end

        def clear
          local_cache.clear if local_cache
          super
        end

        private
          def thread_local_key
            @thread_local_key ||= "#{self.class.name.underscore}_local_cache".gsub("/", "_").to_sym
          end

          def local_cache
            Thread.current[thread_local_key]
          end
      end
    end
  end
end
