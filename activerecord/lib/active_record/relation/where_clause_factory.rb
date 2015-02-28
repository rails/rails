module ActiveRecord
  class Relation
    class WhereClauseFactory
      def initialize(klass, predicate_builder)
        @klass = klass
        @predicate_builder = predicate_builder
      end

      def build(opts, other)
        binds = []

        case opts
        when String, Array
          parts = [klass.send(:sanitize_sql, other.empty? ? opts : ([opts] + other))]
        when Hash
          attributes = predicate_builder.resolve_column_aliases(opts)
          attributes = klass.send(:expand_hash_conditions_for_aggregates, attributes)

          attributes, binds = predicate_builder.create_binds(attributes)

          parts = predicate_builder.build_from_hash(attributes)
        else
          parts = [opts]
        end

        WhereClause.new(parts, binds)
      end

      protected

      attr_reader :klass, :predicate_builder
    end
  end
end
