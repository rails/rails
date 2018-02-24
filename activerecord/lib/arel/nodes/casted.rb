# frozen_string_literal: true

module Arel
  module Nodes
    class Casted < Arel::Nodes::NodeExpression # :nodoc:
      attr_reader :val, :attribute
      def initialize(val, attribute)
        @val       = val
        @attribute = attribute
        super()
      end

      def nil?; @val.nil?; end

      def hash
        [self.class, val, attribute].hash
      end

      def eql?(other)
        self.class == other.class &&
            self.val == other.val &&
            self.attribute == other.attribute
      end
      alias :== :eql?
    end

    class Quoted < Arel::Nodes::Unary # :nodoc:
      alias :val :value
      def nil?; val.nil?; end
    end

    def self.build_quoted(other, attribute = nil)
      case other
      when Arel::Nodes::Node, Arel::Attributes::Attribute, Arel::Table, Arel::Nodes::BindParam, Arel::SelectManager, Arel::Nodes::Quoted, Arel::Nodes::SqlLiteral
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
