# frozen_string_literal: true

module ActiveRecord
  module OptimisticUpdate
    def update_if(*args, &block)
      @_optimistic_update_constraints << args

      if block_given?
        begin
          yield
        ensure
          clear_update_conditions
        end
      else
        self
      end
    end

    def clear_update_conditions
      @_optimistic_update_constraints = []
    end

    def decrement!(...)
      super(...)
    rescue ActiveRecord::UnexpectedValueInDatabase => e
      raise ActiveRecord::UnexpectedValueInDatabase.new(self, "decrement!", e.constraints)
    end

    def update_columns(attributes)
      return super if @_optimistic_update_constraints.empty?

      _with_scope do |scope|
        super.tap do |success|
          raise ActiveRecord::UnexpectedValueInDatabase.new(self, "update", scope.arel.where_sql) unless success
        end
      end
    end

    private
      def init_internals
        super
        @_optimistic_update_constraints = []
      end

      def _update_row(attribute_names, attempted_action = "update")
        return super if @_optimistic_update_constraints.empty?

        _with_scope do |scope|
          super.tap do |affected_rows|
            if affected_rows != 1
              raise ActiveRecord::UnexpectedValueInDatabase.new(self, attempted_action, scope.arel.where_sql)
            end
          end
        rescue ActiveRecord::StaleObjectError => e
          # To make things more explicit for developers, append the optimistic lock condition to the error message:
          locking_column = self.class.locking_column
          full_constraints = scope.arel.where_sql.to_s + " AND #{locking_column} = #{_lock_value_for_database(locking_column)}"
          raise ActiveRecord::UnexpectedValueInDatabase.new(e.record, e.attempted_action, full_constraints)
        end
      end

      def _combine_constraints(relation = self.class.all)
        return if @_optimistic_update_constraints.empty?

        @_optimistic_update_constraints.reduce(relation) do |relation, constraint|
          relation.where(*constraint)
        end
      end

      def _with_scope(&block)
        scoped_relation = _combine_constraints(self.class.unscoped)
        scoped_relation.scoping(all_queries: true) do
          yield scoped_relation
        end
      end

      def _increment(id, counters)
        return super if @_optimistic_update_constraints.empty?

        _with_scope do |scope|
          # Ideally we could use self.class.update_counters(id, counters), but it uses `unscoped` so we can't
          # See: https://github.com/rails/rails/pull/47358
          self.class.all.where!(self.class.primary_key => id).update_counters(counters).tap do |affected_rows|
            if affected_rows != 1
              raise ActiveRecord::UnexpectedValueInDatabase.new(self, "increment!", scope.arel.where_sql)
            end
          end
        end
      end
  end
end
