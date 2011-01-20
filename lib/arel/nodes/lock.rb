module Arel
  module Nodes
    class Lock < Arel::Nodes::Node
      attr_reader :locking
      def initialize locking = true
        @locking = locking
      end
    end
  end
end
