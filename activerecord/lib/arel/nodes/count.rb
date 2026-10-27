# frozen_string_literal: true

# :markup: markdown
module Arel # :nodoc: all
  module Nodes
    class Count < Arel::Nodes::Function
      def initialize(expr, distinct = false)
        super(expr)
        @distinct = distinct
      end
    end
  end
end
