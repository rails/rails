# frozen_string_literal: true

module Arel # :nodoc: all
  module Nodes
    class ValuesList < Unary
      alias :rows :expr
    end
  end
end
