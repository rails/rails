# frozen_string_literal: true

require "concurrent/map"

module ActiveRecord
  module ConnectionAdapters # :nodoc:
    module QueryCache
      class << self
        def included(base) # :nodoc:
          dirties_query_cache base, :create, :insert, :update, :delete, :truncate, :truncate_tables,
            :rollback_to_savepoint, :rollback_db_transaction, :restart_db_transaction, :exec_insert_all

          base.set_callback :checkout, :after, :configure_query_cache!
          base.set_callback :checkin, :after, :disable_query_cache!
        end

        def dirties_query_cache(base, *method_names)
          method_names.each do |method_name|
            base.class_eval <<-end_code, __FILE__, __LINE__ + 1
              def #{method_name}(*)
                ActiveRecord::Base.clear_query_caches_for_current_thread
                super
              end
            end_code
          end
        end
      end

      module ConnectionPoolConfiguration
        def initialize(*)
          super
          @query_cache_enabled = Concurrent::Map.new { false }
        end

        def enable_query_cache!
          @query_cache_enabled[connection_cache_key(current_thread)] = true
          connection.enable_query_cache! if active_connection?
        end

        def disable_query_cache!
          @query_cache_enabled.delete connection_cache_key(current_thread)
          connection.disable_query_cache! if active_connection?
        end

        def query_cache_enabled
          @query_cache_enabled[connection_cache_key(current_thread)]
        end
      end

      attr_reader :query_cache, :query_cache_enabled

      def initialize(*)
        super
        @query_cache         = Hash.new { |h, sql| h[sql] = {} }
        @query_cache_enabled = false
      end

      # Enable the query cache within the block.
      def cache
        old, @query_cache_enabled = @query_cache_enabled, true
        yield
      ensure
        @query_cache_enabled = old
        clear_query_cache unless @query_cache_enabled
      end

      def enable_query_cache!
        @query_cache_enabled = true
      end

      def disable_query_cache!
        @query_cache_enabled = false
        clear_query_cache
      end

      # Disable the query cache within the block.
      def uncached
        old, @query_cache_enabled = @query_cache_enabled, false
        yield
      ensure
        @query_cache_enabled = old
      end

      # Clears the query cache.
      #
      # One reason you may wish to call this method explicitly is between queries
      # that ask the database to randomize results. Otherwise the cache would see
      # the same SQL query and repeatedly return the same result each time, silently
      # undermining the randomness you were expecting.
      def clear_query_cache
        @lock.synchronize do
          @query_cache.clear
        end
      end

      def select_all(arel, name = nil, binds = [], preparable: nil, async: false)
        arel = arel_from_relation(arel)

        # If arel is locked this is a SELECT ... FOR UPDATE or somesuch.
        # Such queries should not be cached.
        if @query_cache_enabled && !(arel.respond_to?(:locked) && arel.locked)
          sql, binds, preparable = to_sql_and_binds(arel, binds, preparable)

          if async
            lookup_sql_cache(sql, name, binds) || super(sql, name, binds, preparable: preparable, async: async)
          else
            cache_sql(sql, name, binds) { super(sql, name, binds, preparable: preparable, async: async) }
          end
        else
          super
        end
      end

      private
        def lookup_sql_cache(sql, name, binds)
          @lock.synchronize do
            if @query_cache[sql].key?(binds)
              ActiveSupport::Notifications.instrument(
                "sql.active_record",
                cache_notification_info(sql, name, binds)
              )
              @query_cache[sql][binds]
            end
          end
        end

        def cache_sql(sql, name, binds)
          @lock.synchronize do
            result =
              if @query_cache[sql].key?(binds)
                ActiveSupport::Notifications.instrument(
                  "sql.active_record",
                  cache_notification_info(sql, name, binds)
                )
                @query_cache[sql][binds]
              else
                @query_cache[sql][binds] = yield
              end
            result.dup
          end
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

        def configure_query_cache!
          enable_query_cache! if pool.query_cache_enabled
        end
    end
  end
end
