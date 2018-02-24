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

    %w{
      As
      Assignment
      Between
      GreaterThan
      GreaterThanOrEqual
      Join
      LessThan
      LessThanOrEqual
      NotEqual
      NotIn
      Or
      Union
      UnionAll
      Intersect
      Except
    }.each do |name|
      const_set name, Class.new(Binary)
    end
  end
end
