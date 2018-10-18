# frozen_string_literal: true

module Arel # :nodoc: all
  module Nodes
    class StringJoin < Arel::Nodes::Join
      def initialize(left, right = nil)
        super
      end
    end
  end
end
