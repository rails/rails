# frozen_string_literal: true

module Arel # :nodoc: all
  module Nodes
    class Binary < Arel::Nodes::NodeExpression
      attr_accessor :left, :right

      def initialize(left, right)
        super()
        @left  = left
        @right = right
      end

      def initialize_copy(other)
        super
        @left  = @left.clone if @left
        @right = @right.clone if @right
      end

      def hash
        [self.class, @left, @right].hash
      end

      def eql?(other)
        self.class == other.class &&
          self.left == other.left &&
          self.right == other.right
      end
      alias :== :eql?
    end

    module FetchAttribute
      def fetch_attribute
        if left.is_a?(Arel::Attributes::Attribute)
          yield left
        elsif right.is_a?(Arel::Attributes::Attribute)
          yield right
        end
      end
    end

    class Between < Binary; include FetchAttribute; end

    class GreaterThan < Binary
      include FetchAttribute

      def invert
        Arel::Nodes::LessThanOrEqual.new(left, right)
      end
    end

    class GreaterThanOrEqual < Binary
      include FetchAttribute

      def invert
        Arel::Nodes::LessThan.new(left, right)
      end
    end

    class LessThan < Binary
      include FetchAttribute

      def invert
        Arel::Nodes::GreaterThanOrEqual.new(left, right)
      end
    end

    class LessThanOrEqual < Binary
      include FetchAttribute

      def invert
        Arel::Nodes::GreaterThan.new(left, right)
      end
    end

    class NotEqual < Binary
      include FetchAttribute

      def invert
        Arel::Nodes::Equality.new(left, right)
      end
    end

    class NotIn < Binary
      include FetchAttribute

      def invert
        Arel::Nodes::In.new(left, right)
      end
    end

    class Or < Binary
      def fetch_attribute(&block)
        left.fetch_attribute(&block) && right.fetch_attribute(&block)
      end
    end

    %w{
      As
      Assignment
      Join
      Union
      UnionAll
      Intersect
      Except
    }.each do |name|
      const_set name, Class.new(Binary)
    end
  end
end
