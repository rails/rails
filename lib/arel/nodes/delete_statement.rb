module Arel
  module Nodes
    class DeleteStatement
      attr_accessor :relation, :wheres

      def initialize
        @from   = nil
        @wheres = []
      end
    end
  end
end
