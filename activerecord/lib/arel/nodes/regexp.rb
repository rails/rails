# frozen_string_literal: true

module Arel # :nodoc: all
  module Nodes
    class Regexp < Binary
      attr_accessor :case_sensitive

      def initialize(left, right, case_sensitive = true)
        super(left, right)
        @case_sensitive = case_sensitive
      end

      def invert
        Arel::Nodes::NotRegexp.new(left, right, case_sensitive)
      end
    end

    class NotRegexp < Regexp
      def invert
        Arel::Nodes::Regexp.new(left, right, case_sensitive)
      end
    end
  end
end
