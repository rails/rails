# frozen_string_literal: true

module Arel # :nodoc: all
  module Nodes
    class Over < Binary
      include Arel::AliasPredication

      def initialize(left, right = nil)
        super(left, right)
      end

      def operator; "OVER" end
    end
  end
end
