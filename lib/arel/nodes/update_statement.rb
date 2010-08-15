module Arel
  module Nodes
    class UpdateStatement
      attr_accessor :relation, :wheres, :values

      def initialize
        @relation = nil
        @wheres   = []
        @values   = nil
      end
    end
  end
end
