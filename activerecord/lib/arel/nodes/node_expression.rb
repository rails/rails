# frozen_string_literal: true

# :markup: markdown
module Arel # :nodoc: all
  module Nodes
    class NodeExpression < Arel::Nodes::Node
      include Arel::Expressions
      include Arel::Predications
      include Arel::AliasPredication
      include Arel::OrderPredications
      include Arel::Math
    end
  end
end
