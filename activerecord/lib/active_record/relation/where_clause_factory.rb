# frozen_string_literal: true

module ActiveRecord
  class Relation
    class WhereClauseFactory # :nodoc:
      def initialize(klass, predicate_builder)
        @klass = klass
        @predicate_builder = predicate_builder
      end

      def build(opts, other)
        case opts
        when String, Array
          parts = [klass.sanitize_sql(other.empty? ? opts : ([opts] + other))]
        when Hash
          attributes = predicate_builder.resolve_column_aliases(opts)
          attributes.stringify_keys!

          parts = predicate_builder.build_from_hash(attributes)
        when Arel::Nodes::Node
          parts = [opts]
        when Symbol
          raise ArgumentError, "do not allow only symbol parameter: #{opts} (#{opts.class}" if other.blank?

          if klass.attribute_alias?(opts)
            original_column = klass.attribute_alias(opts)
          else
            original_column = opts.to_s
          end
          parts = [ original_column + klass.sanitize_sql(other.size == 1 ? other.first : ([other.first] + other.from(1))) ]
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
