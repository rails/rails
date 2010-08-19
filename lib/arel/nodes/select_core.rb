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
        @froms = @froms.map { |o| o.clone }
        @projections = @projections.map { |o| o.clone }
        @wheres = @wheres.map { |o| o.clone }
      end
    end
  end
end
