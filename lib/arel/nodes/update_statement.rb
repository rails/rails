module Arel
  module Nodes
    class UpdateStatement
      attr_accessor :relation, :wheres

      def initialize
        @relation = nil
        @wheres   = []
      end
    end
  end
end
