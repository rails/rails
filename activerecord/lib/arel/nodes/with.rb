# frozen_string_literal: true

# :markup: markdown
module Arel # :nodoc: all
  module Nodes
    class With < Arel::Nodes::Unary
      alias children expr
    end

    class WithRecursive < With; end
  end
end
