module Arel
  module Nodes
    class UpdateStatement < Arel::Nodes::Node
      attr_accessor :relation, :wheres, :values, :orders, :limit

      def initialize
        @relation = nil
        @wheres   = []
        @values   = []
        @orders = []
        @limit  = nil
      end

      def initialize_copy other
        super
        @wheres = @wheres.clone
        @values = @values.clone
      end
    end
  end
end
