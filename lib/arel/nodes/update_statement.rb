module Arel
  module Nodes
    class UpdateStatement
      attr_accessor :relation, :wheres, :values

      def initialize
        @relation = nil
        @wheres   = []
        @values   = []
      end

      def initialize_copy other
        super
        @wheres = @wheres.map { |o| o.clone }
        @values = @values.map { |o| o.clone }
      end
    end
  end
end
