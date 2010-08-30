module Arel
  module Nodes
    class DeleteStatement
      attr_accessor :relation, :wheres

      def initialize
        @from   = nil
        @wheres = []
      end

      def initialize_copy other
        super
        @wheres = @wheres.clone
      end
    end
  end
end
