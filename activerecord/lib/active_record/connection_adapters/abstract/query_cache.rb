# frozen_string_literal: true

require "concurrent/map"

module ActiveRecord
  module ConnectionAdapters # :nodoc:
    module QueryCache
      class << self
        def included(base) #:nodoc:
          dirties_query_cache base, :insert, :update, :delete, :rollback_to_savepoint, :rollback_db_transaction

          base.set_callback :checkin, :after, :clear_query_cache
        end

        def dirties_query_cache(base, *method_names)
          method_names.each do |method_name|
            base.class_eval <<-end_code, __FILE__, __LINE__ + 1
              def #{method_name}(*)
                clear_query_cache if self.query_cache_enabled
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
          @query_cache_enabled[connection_cache_key(Thread.current)] = true
        end

        def disable_query_cache!
          @query_cache_enabled.delete connection_cache_key(Thread.current)
        end

        def query_cache_enabled
          @query_cache_enabled[connection_cache_key(Thread.current)]
        end
      end

      attr_reader :query_cache

      def initialize(*)
        super
        @query_cache = Hash.new { |h, sql| h[sql] = {} }
      end

      def query_cache_enabled
        pool.query_cache_enabled if pool
      end

      # Enable the query cache within the block.
      def cache
        was_enabled = self.query_cache_enabled
        self.enable_query_cache!
        yield
      ensure
        self.disable_query_cache! unless was_enabled
      end

      def enable_query_cache!
        pool.enable_query_cache!
      end

      def disable_query_cache!
        pool.disable_query_cache!
        clear_query_cache
      end

      # Disable the query cache within the block.
      def uncached
        was_enabled = self.query_cache_enabled
        pool.disable_query_cache!
        yield
      ensure
        self.enable_query_cache! if was_enabled
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

      def select_all(arel, name = nil, binds = [], preparable: nil)
        if query_cache_enabled && !locked?(arel)
          arel = arel_from_relation(arel)
          sql, binds = to_sql_and_binds(arel, binds)
          cache_sql(sql, name, binds) { super(sql, name, binds, preparable: preparable) }
        else
          super
        end
      end

      private

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
            connection_id: object_id,
            cached: true
          }
        end

        # If arel is locked this is a SELECT ... FOR UPDATE or somesuch. Such
        # queries should not be cached.
        def locked?(arel)
          arel = arel.arel if arel.is_a?(Relation)
          arel.respond_to?(:locked) && arel.locked
        end
    end
  end
end
