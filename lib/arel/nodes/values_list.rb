# frozen_string_literal: true
module Arel
  module Nodes
    class ValuesList < Node
      attr_reader :rows

      def initialize(rows)
        @rows = rows
        super()
      end
    end
  end
end
