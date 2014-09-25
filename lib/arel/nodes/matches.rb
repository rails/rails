module Arel
  module Nodes
    class Matches < Binary
      attr_reader :escape

      def initialize(left, right, escape = nil)
        super(left, right)
        @escape = escape && Nodes.build_quoted(escape)
      end
    end

    class DoesNotMatch < Matches; end
  end
end
