# frozen_string_literal: true

module Arel # :nodoc: all
  module Nodes
    class Regexp < Binary
      attr_accessor :case_sensitive

      def initialize(left, right, case_sensitive = true)
        super(left, right)
        @case_sensitive = case_sensitive
      end
    end

    class NotRegexp < Regexp; end
  end
end
