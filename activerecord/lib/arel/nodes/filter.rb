# frozen_string_literal: true

module Arel
  module Nodes
    class Filter < Binary
      include Arel::WindowPredications
      include Arel::AliasPredication
    end
  end
end
