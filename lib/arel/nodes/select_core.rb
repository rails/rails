module Arel
  module Nodes
    class SelectCore
      attr_reader :froms, :projections, :wheres

      def initialize
        @froms       = []
        @projections = []
        @wheres      = []
      end

      def initialize_copy other
        super
        @froms = @froms.clone
        @projections = @projections.clone
        @wheres = @wheres.clone
      end
    end
  end
end
