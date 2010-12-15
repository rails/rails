module Arel
  module Nodes
    class Binary < Arel::Nodes::Node
      attr_accessor :left, :right

      def initialize left, right
        @left  = left
        @right = right
      end

      def initialize_copy other
        super
        @left  = @left.clone if @left
        @right = @right.clone if @right
      end
    end

    %w{
      Between
      NotEqual
      Assignment
      Or
      As
      GreaterThan
      GreaterThanOrEqual
      LessThan
      LessThanOrEqual
      Matches
      DoesNotMatch
      NotIn
      Join
    }.each do |name|
      const_set(name, Class.new(Binary))
    end
  end
end
