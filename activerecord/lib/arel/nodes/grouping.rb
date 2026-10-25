# frozen_string_literal: true

# :markup: markdown
module Arel # :nodoc: all
  module Nodes
    class Grouping < Unary
      def fetch_attribute(&block)
        expr.fetch_attribute(&block)
      end
    end
  end
end
