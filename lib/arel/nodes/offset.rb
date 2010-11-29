module Arel
  module Nodes
    class Offset < Arel::Nodes::Unary
      alias :value :expr
    end
  end
end
