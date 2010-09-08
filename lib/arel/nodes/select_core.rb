module Arel
  module Nodes
    class SelectCore
      attr_reader :froms, :projections, :wheres, :groups
      attr_accessor :having

      def initialize
        @froms       = []
        @projections = []
        @wheres      = []
        @groups      = []
        @having      = nil
      end

      def initialize_copy other
        super
        @froms       = @froms.clone
        @projections = @projections.clone
        @wheres      = @wheres.clone
        @group       = @groups.clone
        @having      = @having.clone if @having
      end
    end
  end
end
