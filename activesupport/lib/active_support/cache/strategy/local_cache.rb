# frozen_string_literal: true

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
          class Entry # :nodoc:
            class << self
              def build(cache_entry)
                return if cache_entry.nil?
                return cache_entry if cache_entry.compressed?

                value = cache_entry.value
                if value.is_a?(String)
                  DupableEntry.new(cache_entry)
                elsif !value || value == true || value.is_a?(Numeric)
                  new(cache_entry)
                else
                  MutableEntry.new(cache_entry)
                end
              end
            end

            attr_reader :value, :version
            attr_accessor :expires_at

            def initialize(cache_entry)
              @value = cache_entry.value
              @expires_at = cache_entry.expires_at
              @version = cache_entry.version
            end

            def local?
              true
            end

            def compressed?
              false
            end

            def mismatched?(version)
              @version && version && @version != version
            end

            def expired?
              expires_at && expires_at <= Time.now.to_f
            end

            def marshal_dump
              raise NotImplementedError, "LocalStore::Entry should never be serialized"
            end
          end

          class DupableEntry < Entry # :nodoc:
            def initialize(_cache_entry)
              super
              unless @value.frozen?
                @value = @value.dup.freeze
              end
            end

            def value
              @value.dup
            end
          end

          class MutableEntry < Entry # :nodoc:
            def initialize(cache_entry)
              @payload = Marshal.dump(cache_entry.value)
              @expires_at = cache_entry.expires_at
              @version = cache_entry.version
            end

            def value
              Marshal.load(@payload)
            end
          end

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

          def read_entry(key, **options)
            @data[key]
          end

          def read_multi_entries(keys, **options)
            values = {}

            keys.each do |name|
              entry = read_entry(name, **options)
              values[name] = entry.value if entry
            end

            values
          end

          def write_entry(key, entry, **options)
            @data[key] = Entry.build(entry)
            true
          end

          def delete_entry(key, **options)
            !!@data.delete(key)
          end

          def fetch_entry(key, options = nil) # :nodoc:
            @data.fetch(key) { @data[key] = Entry.build(yield) }
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

        def clear(**options) # :nodoc:
          return super unless cache = local_cache
          cache.clear(options)
          super
        end

        def cleanup(**options) # :nodoc:
          return super unless cache = local_cache
          cache.clear
          super
        end

        def delete_matched(matcher, options = nil) # :nodoc:
          return super unless cache = local_cache
          cache.clear
          super
        end

        def increment(name, amount = 1, **options) # :nodoc:
          return super unless local_cache
          value = bypass_local_cache { super }
          write_cache_value(name, value, **options)
          value
        end

        def decrement(name, amount = 1, **options) # :nodoc:
          return super unless local_cache
          value = bypass_local_cache { super }
          write_cache_value(name, value, **options)
          value
        end

        private
          def read_entry(key, **options)
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

          def read_multi_entries(keys, **options)
            return super unless local_cache

            local_entries = local_cache.read_multi_entries(keys, **options)
            missed_keys = keys - local_entries.keys

            if missed_keys.any?
              local_entries.merge!(super(missed_keys, **options))
            else
              local_entries
            end
          end

          def write_entry(key, entry, **options)
            if options[:unless_exist]
              local_cache.delete_entry(key, **options) if local_cache
            else
              local_cache.write_entry(key, entry, **options) if local_cache
            end


            if entry.local?
              super(key, new_entry(entry.value, options), **options)
            else
              super
            end
          end

          def delete_entry(key, **options)
            local_cache.delete_entry(key, **options) if local_cache
            super
          end

          def write_cache_value(name, value, **options)
            name = normalize_key(name, options)
            cache = local_cache
            cache.mute do
              if value
                cache.write(name, value, options)
              else
                cache.delete(name, **options)
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
