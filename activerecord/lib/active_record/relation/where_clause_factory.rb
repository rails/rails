# frozen_string_literal: true

module ActiveRecord
  class Relation
    class WhereClauseFactory # :nodoc:
      def initialize(scope)
        @scope = scope
        @klass = scope.klass
        @predicate_builder = scope.predicate_builder
      end

      def build(opts, other)
        case opts
        when String, Array
          parts = [klass.sanitize_sql(other.empty? ? opts : ([opts] + other))]
        when Hash
          attributes = predicate_builder.resolve_column_aliases(opts)
          attributes = klass.send(:expand_hash_conditions_for_aggregates, attributes)
          attributes.stringify_keys!

          parts = predicate_builder.build_from_hash(attributes)
        when Arel::Nodes::Node
          parts = [opts]
        else
          raise ArgumentError, "Unsupported argument type: #{opts} (#{opts.class})"
        end

        WhereClause.new(parts)
      end

      # TODO: This is messy. Rewrite it all
      # Will probably include some refactoring of both WhereClauseFactory and PredicateBuilder
      def build_comparison(comparison, column_name, value)
        if column_name.to_s.include?(".".freeze)
          table_name, col_name = column_name.to_s.split(".".freeze)
          references_scope = table_name.classify.constantize

          # This seems like the wrong place for this
          scope.references!(table_name)

          column = references_scope.arel_table[col_name]
          builder = references_scope.predicate_builder
        else
          column = scope.arel_table[column_name]
          builder = predicate_builder
        end

        bind = predicate_builder.build_bind_attribute(column_name, value)

        WhereClause.new([column.send(comparison, bind)])
      end

      private
        attr_reader :scope, :klass, :predicate_builder
    end
  end
end
