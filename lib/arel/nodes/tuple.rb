# frozen_string_literal: true
module Arel
  module Nodes
    class Tuple < Node
      attr_reader :values

      def initialize(values)
        @values = values
        super()
      end
    end
  end
end
