# frozen_string_literal: true

module Arel # :nodoc: all
  module Nodes
    class ValuesList < Node
      attr_reader :rows

      def initialize(rows)
        @rows = rows
        super()
      end

      def hash
        @rows.hash
      end

      def eql?(other)
        self.class == other.class &&
          self.rows == other.rows
      end
      alias :== :eql?
    end
  end
end
