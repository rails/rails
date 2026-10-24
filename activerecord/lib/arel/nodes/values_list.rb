# frozen_string_literal: true

# :markup: markdown
module Arel # :nodoc: all
  module Nodes
    class ValuesList < Unary
      alias :rows :expr
    end
  end
end
