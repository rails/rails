module Arel
  module Nodes
    class SqlLiteral < String
      include Arel::Expressions
    end
  end
end
