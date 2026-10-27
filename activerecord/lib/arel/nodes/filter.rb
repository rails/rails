# frozen_string_literal: true

# :markup: markdown
module Arel # :nodoc: all
  module Nodes
    class Filter < Binary
      include Arel::WindowPredications
      include Arel::AliasPredication
    end
  end
end
