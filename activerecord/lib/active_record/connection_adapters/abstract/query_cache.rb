# frozen_string_literal: true

require "concurrent/map"
require "concurrent/atomic/atomic_fixnum"

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
                if pool.dirties_query_cache
                  ActiveRecord::Base.clear_query_caches_for_current_thread
                end
                super
              end
            end_code
          end
        end
      end

      class Store # :nodoc:
        attr_accessor :enabled, :dirties
        alias_method :enabled?, :enabled
        alias_method :dirties?, :dirties

        def initialize(version, max_size)
          @version = version
          @current_version = version.value
          @map = {}
          @max_size = max_size
          @enabled = false
          @dirties = true
        end

        def size
          check_version
          @map.size
        end

        def empty?
          check_version
          @map.empty?
        end

        def [](key)
          check_version
          return unless @enabled

          if entry = @map.delete(key)
            @map[key] = entry
          end
        end

        def compute_if_absent(key)
          check_version

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

        private
          def check_version
            if @current_version != @version.value
              @map.clear
              @current_version = @version.value
            end
          end
      end

      class QueryCacheRegistry # :nodoc:
        def initialize
          @mutex = Mutex.new
          @map = ConnectionPool::WeakThreadKeyMap.new
        end

        def compute_if_absent(context)
          @map[context] || @mutex.synchronize do
            @map[context] ||= yield
          end
        end

        def clear
          @map.synchronize do
            @map.clear
          end
        end
      end

      module ConnectionPoolConfiguration # :nodoc:
        def initialize(...)
          super
          @query_cache_version = Concurrent::AtomicFixnum.new
          @thread_query_caches = QueryCacheRegistry.new
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

        def checkout_and_verify(connection)
          super
          connection.query_cache ||= query_cache
          connection
        end

        # Disable the query cache within the block.
        def disable_query_cache(dirties: true)
          cache = query_cache
          old_enabled, cache.enabled, old_dirties, cache.dirties = cache.enabled, false, cache.dirties, dirties
          begin
            yield
          ensure
            cache.enabled, cache.dirties = old_enabled, old_dirties
          end
        end

        def enable_query_cache
          cache = query_cache
          old_enabled, cache.enabled, old_dirties, cache.dirties = cache.enabled, true, cache.dirties, true
          begin
            yield
          ensure
            cache.enabled, cache.dirties = old_enabled, old_dirties
          end
        end

        def enable_query_cache!
          query_cache.enabled = true
          query_cache.dirties = true
        end

        def disable_query_cache!
          query_cache.enabled = false
          query_cache.dirties = true
        end

        def query_cache_enabled
          query_cache.enabled
        end

        def dirties_query_cache
          query_cache.dirties
        end

        def clear_query_cache
          if @pinned_connection
            # With transactional fixtures, and especially systems test
            # another thread may use the same connection, but with a different
            # query cache. So we must clear them all.
            @query_cache_version.increment
          end
          query_cache.clear
        end

        def query_cache
          @thread_query_caches.compute_if_absent(ActiveSupport::IsolatedExecutionState.context) do
            Store.new(@query_cache_version, @query_cache_max_size)
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
      def cache(&block)
        pool.enable_query_cache(&block)
      end

      def enable_query_cache!
        pool.enable_query_cache!
      end

      # Disable the query cache within the block.
      #
      # Set <tt>dirties: false</tt> to prevent query caches on all connections from being cleared by write operations.
      # (By default, write operations dirty all connections' query caches in case they are replicas whose cache would now be outdated.)
      def uncached(dirties: true, &block)
        pool.disable_query_cache(dirties: dirties, &block)
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

      def select_all(arel, name = nil, binds = [], preparable: nil, async: false, allow_retry: false) # :nodoc:
        arel = arel_from_relation(arel)

        # If arel is locked this is a SELECT ... FOR UPDATE or somesuch.
        # Such queries should not be cached.
        if @query_cache&.enabled? && !(arel.respond_to?(:locked) && arel.locked)
          sql, binds, preparable, allow_retry = to_sql_and_binds(arel, binds, preparable, allow_retry)

          if async
            result = lookup_sql_cache(sql, name, binds) || super(sql, name, binds, preparable: preparable, async: async, allow_retry: allow_retry)
            FutureResult.wrap(result)
          else
            cache_sql(sql, name, binds) { super(sql, name, binds, preparable: preparable, async: async, allow_retry: allow_retry) }
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
              cache_notification_info_result(sql, name, binds, result)
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
              cache_notification_info_result(sql, name, binds, result)
            )
          end

          result.dup
        end

        def cache_notification_info_result(sql, name, binds, result)
          payload = cache_notification_info(sql, name, binds)
          payload[:row_count] = result.length
          payload
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
            transaction: current_transaction.user_transaction.presence,
            cached: true
          }
        end
    end
  end
end
