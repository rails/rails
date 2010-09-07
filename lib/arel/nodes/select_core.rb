module Arel
  module Nodes
    class SelectCore
      attr_reader :froms, :projections, :wheres, :groups

      def initialize
        @froms       = []
        @projections = []
        @wheres      = []
        @groups      = []
      end

      def initialize_copy other
        super
        @froms       = @froms.clone
        @projections = @projections.clone
        @wheres      = @wheres.clone
        @group       = @groups.clone
      end
    end
  end
end
