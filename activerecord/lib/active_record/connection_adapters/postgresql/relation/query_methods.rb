module ActiveRecord
  module QueryMethods
    class StoreChain
      def initialize(scope, store_name)
        @scope = scope
        @store_name = store_name
      end

      def key(key)
        update_scope "#{@store_name} ? :key", key: key.to_s
      end

      def keys(*keys)
        update_scope "#{@store_name} ?& ARRAY[:keys]", keys: keys.map(&:to_s)
      end

      def any(*keys)
        update_scope "#{@store_name} ?| ARRAY[:keys]", keys: keys.map(&:to_s)
      end

      def contain(opts)
        update_scope "#{@store_name} @> :data", data: @scope.table.type_cast_for_database(@store_name, opts)
      end

      def contained(opts)
        update_scope "#{@store_name} <@ :data", data: @scope.table.type_cast_for_database(@store_name, opts)
      end

      private

      def update_scope(*opts)
        where_clause = @scope.send(:where_clause_factory).build(opts, {})
        @scope.where_clause += where_clause
        @scope
      end
    end

    class WhereChain
      def store(store_name, opts = nil)
        # TODO: validate that store is queryable
        if opts.nil?
          # We want to use store-specific operator
          StoreChain.new(@scope, store_name.to_s)
        else
          # We want to query by store key value
          opts.each do |k,v|
            where_clause = @scope.send(:where_clause_factory).build(
              ["#{store_name}->:key = :val", key: k, val: v.to_s],
              {}
            )
            @scope.where_clause += where_clause
          end
          @scope
        end
      end
    end
  end
end
