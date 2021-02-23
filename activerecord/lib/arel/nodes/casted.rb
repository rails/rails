# frozen_string_literal: true

module Arel # :nodoc: all
  module Nodes
    class Casted < Arel::Nodes::NodeExpression # :nodoc:
      attr_reader :value, :attribute
      alias :value_before_type_cast :value

      def initialize(value, attribute)
        @value     = value
        @attribute = attribute
        super()
      end

      def nil?; value.nil?; end

      def value_for_database
        if attribute.able_to_type_cast?
          attribute.type_cast_for_database(value)
        else
          value
        end
      end

      def hash
        [self.class, value, attribute].hash
      end

      def eql?(other)
        self.class == other.class &&
          self.value == other.value &&
          self.attribute == other.attribute
      end
      alias :== :eql?
    end

    class Quoted < Arel::Nodes::Unary # :nodoc:
      alias :value_for_database :value
      alias :value_before_type_cast :value

      def nil?; value.nil?; end

      def infinite?
        value.respond_to?(:infinite?) && value.infinite?
      end
    end

    def self.build_quoted(other, attribute = nil)
      case other
      when Arel::Nodes::Node, Arel::Attributes::Attribute, Arel::Table, Arel::SelectManager, Arel::Nodes::SqlLiteral
        other
      else
        case attribute
        when Arel::Attributes::Attribute
          Casted.new other, attribute
        else
          Quoted.new other
        end
      end
    end
  end
end
