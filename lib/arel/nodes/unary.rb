module Arel
  module Nodes
    class Unary < Arel::Nodes::Node
      attr_accessor :expr
      alias :value :expr

      def initialize expr
        @expr = expr
      end
    end

    %w{
      Bin
      Group
      Grouping
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
