module ActiveRecord
  module ConnectionAdapters # :nodoc:
    module QueryCache
      class << self
        def included(base) #:nodoc:
          dirties_query_cache base, :insert, :update, :delete, :rollback_to_savepoint, :rollback_db_transaction
          base.set_callback :checkin, :after, :disable_query_cache!
        end

        def dirties_query_cache(base, *method_names)
          method_names.each do |method_name|
            base.class_eval <<-end_code, __FILE__, __LINE__ + 1
              def #{method_name}(*)
                clear_query_cache if @query_cache_enabled
                super
              end
            end_code
          end
        end
      end

      attr_reader :query_cache, :query_cache_enabled

      def initialize(*)
        super
        @query_cache         = Hash.new { |h,sql| h[sql] = {} }
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
        @query_cache.clear
      end

      def select_all(arel, name = nil, binds = [], preparable: nil)
        if @query_cache_enabled && !locked?(arel)
          arel, binds = binds_from_relation arel, binds
          sql = to_sql(arel, binds)
          cache_sql(sql, name, binds) { super(sql, name, binds, preparable: preparable) }
        else
          super
        end
      end

      private

        def cache_sql(sql, name, binds)
          result =
            if @query_cache[sql].key?(binds)
              ActiveSupport::Notifications.instrument(
                "sql.active_record",
                sql: sql,
                binds: binds,
                name: name,
                connection_id: object_id,
                cached: true,
              )
              @query_cache[sql][binds]
            else
              @query_cache[sql][binds] = yield
            end
          result.dup
        end

        # If arel is locked this is a SELECT ... FOR UPDATE or somesuch. Such
        # queries should not be cached.
        def locked?(arel)
          arel.respond_to?(:locked) && arel.locked
        end
    end
  end
end
