# :markup: markdown
# frozen_string_literal: true

require "active_record/relation/query_attribute"

module ActiveRecord
  class PredicateBuilder
    class ComparisonAttribute < Arel::Attributes::Attribute # :nodoc:
      attr_reader :attribute, :expression, :type_caster

      def initialize(attribute, type_caster)
        super(attribute.relation, attribute.name)
        @attribute = attribute
        @type_caster = type_caster
        @expression = comparison_expression(attribute)
      end

      def comparison_expression(expression)
        type_caster.comparison_expression(expression)
      end

      delegate :able_to_type_cast?, :type_cast_for_database, to: :attribute

      def fetch_attribute(&)
        attribute.fetch_attribute(&)
      end

      def hash
        [self.class, attribute, expression].hash
      end

      def ==(other)
        self.class == other.class &&
          attribute == other.attribute &&
          expression == other.expression
      end
      alias eql? ==
    end

    class ComparisonValue < Arel::Nodes::NodeExpression # :nodoc:
      attr_reader :expression, :query_attribute

      def initialize(query_attribute)
        @query_attribute = query_attribute
        @expression = query_attribute.type.comparison_expression(query_attribute)
      end

      delegate :infinite?, :nil?, :unboundable?, :value_before_type_cast, to: :query_attribute

      def hash
        [self.class, expression, query_attribute].hash
      end

      def ==(other)
        self.class == other.class &&
          expression == other.expression &&
          query_attribute == other.query_attribute
      end
      alias eql? ==
    end
  end
end
