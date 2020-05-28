# frozen_string_literal: true

module ActiveRecord
  class Relation
    class WhereClauseFactory # :nodoc:
      def initialize(klass, predicate_builder)
        @klass = klass
        @predicate_builder = predicate_builder
      end

      def build(opts, other, &block)
        case opts
        when String, Array
          parts = [klass.sanitize_sql(other.empty? ? opts : ([opts] + other))]
        when Hash
          parts = predicate_builder.build_from_hash(opts, &block)
        when Arel::Nodes::Node
          parts = [opts]
        else
          raise ArgumentError, "Unsupported argument type: #{opts} (#{opts.class})"
        end

        WhereClause.new(parts)
      end

      private
        attr_reader :klass, :predicate_builder
    end
  end
end
