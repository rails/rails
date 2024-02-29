# frozen_string_literal: true

require "concurrent/map"

module ActiveRecord
  module ConnectionAdapters # :nodoc:
    module QueryCache
      DEFAULT_SIZE = 100 # :nodoc:

      class << self
        def included(base) # :nodoc:
          dirties_query_cache base, :exec_query, :execute, :create, :insert, :update, :delete, :truncate,
            :truncate_tables, :rollback_to_savepoint, :rollback_db_transaction, :restart_db_transaction,
            :exec_insert_all

          base.set_callback :checkin, :after, :unset_query_cache!
        end

        def dirties_query_cache(base, *method_names)
          method_names.each do |method_name|
            base.class_eval <<-end_code, __FILE__, __LINE__ + 1
              def #{method_name}(...)
                ActiveRecord::Base.clear_query_caches_for_current_thread
                super
              end
            end_code
          end
        end
      end

      class Store # :nodoc:
        attr_accessor :enabled
        alias_method :enabled?, :enabled

        def initialize(max_size)
          @map = {}
          @max_size = max_size
          @enabled = false
        end

        def size
          @map.size
        end

        def empty?
          @map.empty?
        end

        def [](key)
          return unless @enabled

          if entry = @map.delete(key)
            @map[key] = entry
          end
        end

        def compute_if_absent(key)
          return yield unless @enabled

          if entry = @map.delete(key)
            return @map[key] = entry
          end

          if @max_size && @map.size >= @max_size
            @map.shift # evict the oldest entry
          end

          @map[key] ||= yield
        end

        def clear
          @map.clear
          self
        end
      end

      module ConnectionPoolConfiguration # :nodoc:
        def initialize(...)
          super
          @thread_query_caches = Concurrent::Map.new(initial_capacity: @size)
          @query_cache_max_size = \
            case query_cache = db_config&.query_cache
            when 0, false
              nil
            when Integer
              query_cache
            when nil
              DEFAULT_SIZE
            end
        end

        def checkout(...)
          connection = super
          connection.query_cache ||= query_cache
          connection
        end

        # Disable the query cache within the block.
        def disable_query_cache
          cache = query_cache
          old, cache.enabled = cache.enabled, false
          begin
            yield
          ensure
            cache.enabled = old
          end
        end

        def enable_query_cache
          cache = query_cache
          old, cache.enabled = cache.enabled, true
          begin
            yield
          ensure
            cache.enabled = old
          end
        end

        def enable_query_cache!
          query_cache.enabled = true
        end

        def disable_query_cache!
          query_cache.enabled = false
        end

        def query_cache_enabled
          query_cache.enabled
        end

        def clear_query_cache
          if @pinned_connection
            # With transactional fixtures, and especially systems test
            # another thread may use the same connection, but with a different
            # query cache. So we must clear them all.
            @thread_query_caches.each_value(&:clear)
          else
            query_cache.clear
          end
        end

        private
          def prune_thread_cache
            super
            dead_threads = @thread_query_caches.keys.reject(&:alive?)
            dead_threads.each do |dead_thread|
              @thread_query_caches.delete(dead_thread)
            end
          end

          def query_cache
            @thread_query_caches.compute_if_absent(ActiveSupport::IsolatedExecutionState.context) do
              Store.new(@query_cache_max_size)
            end
          end
      end

      attr_accessor :query_cache

      def initialize(*)
        super
        @query_cache = nil
      end

      def query_cache_enabled
        @query_cache&.enabled?
      end

      # Enable the query cache within the block.
      def cache(&)
        pool.enable_query_cache(&)
      end

      def enable_query_cache!
        pool.enable_query_cache!
      end

      # Disable the query cache within the block.
      def uncached(&)
        pool.disable_query_cache(&)
      end

      def disable_query_cache!
        pool.disable_query_cache!
      end

      # Clears the query cache.
      #
      # One reason you may wish to call this method explicitly is between queries
      # that ask the database to randomize results. Otherwise the cache would see
      # the same SQL query and repeatedly return the same result each time, silently
      # undermining the randomness you were expecting.
      def clear_query_cache
        pool.clear_query_cache
      end

      def select_all(arel, name = nil, binds = [], preparable: nil, async: false) # :nodoc:
        arel = arel_from_relation(arel)

        # If arel is locked this is a SELECT ... FOR UPDATE or somesuch.
        # Such queries should not be cached.
        if @query_cache&.enabled? && !(arel.respond_to?(:locked) && arel.locked)
          sql, binds, preparable = to_sql_and_binds(arel, binds, preparable)

          if async
            result = lookup_sql_cache(sql, name, binds) || super(sql, name, binds, preparable: preparable, async: async)
            FutureResult.wrap(result)
          else
            cache_sql(sql, name, binds) { super(sql, name, binds, preparable: preparable, async: async) }
          end
        else
          super
        end
      end

      private
        def unset_query_cache!
          @query_cache = nil
        end

        def lookup_sql_cache(sql, name, binds)
          key = binds.empty? ? sql : [sql, binds]

          result = nil
          @lock.synchronize do
            result = @query_cache[key]
          end

          if result
            ActiveSupport::Notifications.instrument(
              "sql.active_record",
              cache_notification_info(sql, name, binds)
            )
          end

          result
        end

        def cache_sql(sql, name, binds)
          key = binds.empty? ? sql : [sql, binds]
          result = nil
          hit = true

          @lock.synchronize do
            result = @query_cache.compute_if_absent(key) do
              hit = false
              yield
            end
          end

          if hit
            ActiveSupport::Notifications.instrument(
              "sql.active_record",
              cache_notification_info(sql, name, binds)
            )
          end

          result.dup
        end

        # Database adapters can override this method to
        # provide custom cache information.
        def cache_notification_info(sql, name, binds)
          {
            sql: sql,
            binds: binds,
            type_casted_binds: -> { type_casted_binds(binds) },
            name: name,
            connection: self,
            cached: true
          }
        end
    end
  end
end
