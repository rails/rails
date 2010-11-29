module Arel
  module Nodes
    class SelectCore < Arel::Nodes::Node
      attr_accessor :froms, :projections, :wheres, :groups
      attr_accessor :having

      def initialize
        @froms       = nil
        @projections = []
        @wheres      = []
        @groups      = []
        @having      = nil
      end

      def initialize_copy other
        super
        @froms       = @froms.clone if @froms
        @projections = @projections.clone
        @wheres      = @wheres.clone
        @group       = @groups.clone
        @having      = @having.clone if @having
      end
    end
  end
end
