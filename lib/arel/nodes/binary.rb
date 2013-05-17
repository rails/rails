module Arel
  module Nodes
    class Binary < Arel::Nodes::Node
      attr_accessor :left, :right

      def initialize left, right
        super()
        @left  = left
        @right = right
      end

      def initialize_copy other
        super
        @left  = @left.clone if @left
        @right = @right.clone if @right
      end

      def hash
        [@left, @right].hash
      end

      def eql? other
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
      DoesNotMatch
      GreaterThan
      GreaterThanOrEqual
      Join
      LessThan
      LessThanOrEqual
      Matches
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
