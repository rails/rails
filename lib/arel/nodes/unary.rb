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
      Top
      Lock
    }.each do |name|
      const_set(name, Class.new(Unary))
    end

    class Distinct < Unary
      def initialize expr = nil
        super
      end
    end
  end
end
