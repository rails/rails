require 'active_support/core_ext/object/duplicable'

module ActiveRecord
  module ConnectionAdapters # :nodoc:
    module QueryCache
      class << self
        def included(base)
          dirties_query_cache base, :insert, :update, :delete
        end

        def dirties_query_cache(base, *method_names)
          method_names.each do |method_name|
            base.class_eval <<-end_code, __FILE__, __LINE__ + 1
              def #{method_name}(*)                         # def update_with_query_dirty(*args)
                clear_query_cache if @query_cache_enabled   #   clear_query_cache if @query_cache_enabled
                super                                       #   update_without_query_dirty(*args)
              end                                           # end
            end_code
          end
        end
      end

      attr_reader :query_cache, :query_cache_enabled

      # Enable the query cache within the block.
      def cache
        old, @query_cache_enabled = @query_cache_enabled, true
        yield
      ensure
        clear_query_cache
        @query_cache_enabled = old
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

      def select_all(*args)
        if @query_cache_enabled
          cache_sql(args.first) { super }
        else
          super
        end
      end

      def columns(*)
        if @query_cache_enabled
          @query_cache["SHOW FIELDS FROM #{args.first}"] ||= super
        else
          super
        end
      end

      private
        def cache_sql(sql)
          result =
            if @query_cache.has_key?(sql)
              ActiveSupport::Notifications.instrument("sql.active_record",
                :sql => sql, :name => "CACHE", :connection_id => self.object_id)
              @query_cache[sql]
            else
              @query_cache[sql] = yield
            end

          if Array === result
            result.collect { |row| row.dup }
          else
            result.duplicable? ? result.dup : result
          end
        rescue TypeError
          result
        end
    end
  end
end
