module Arel
  module Nodes
    class UpdateStatement < Arel::Nodes::Node
      attr_accessor :relation, :wheres, :values, :orders, :limit
      attr_accessor :key

      def initialize
        @relation = nil
        @wheres   = []
        @values   = []
        @orders   = []
        @limit    = nil
        @key      = nil
      end

      def initialize_copy other
        super
        @wheres = @wheres.clone
        @values = @values.clone
      end
    end
  end
end
