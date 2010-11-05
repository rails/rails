module Arel
  module Nodes
    class Exists < Arel::Nodes::Function
      alias :select_stmt :expressions
    end
  end
end
