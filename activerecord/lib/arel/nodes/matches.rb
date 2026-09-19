# frozen_string_literal: true

module Arel # :nodoc: all
  module Nodes
    class Matches < Binary
      attr_reader :escape
      attr_accessor :case_sensitive

      def initialize(left, right, escape = nil, case_sensitive = false)
        super(left, right)
        @escape = escape && Nodes.build_quoted(escape)
        @case_sensitive = case_sensitive
      end

      def hash
        super ^ [@escape, @case_sensitive].hash
      end

      def eql?(other)
        super &&
          self.escape == other.escape &&
          self.case_sensitive == other.case_sensitive
      end
      alias :== :eql?
    end

    class DoesNotMatch < Matches; end
  end
end
