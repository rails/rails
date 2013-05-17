module Arel
  module Nodes
    class Unary < Arel::Nodes::Node
      attr_accessor :expr
      alias :value :expr

      def initialize expr
        super()
        @expr = expr
      end

      def hash
        @expr.hash
      end

      def eql? other
        self.class == other.class &&
          self.expr == other.expr
      end
      alias :== :eql?
    end

    %w{
      Bin
      Group
      Having
      Limit
      Not
      Offset
      On
      Ordering
      Top
      Lock
      DistinctOn
    }.each do |name|
      const_set(name, Class.new(Unary))
    end
  end
end
