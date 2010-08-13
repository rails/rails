module Arel
  module Nodes
    class InsertStatement
      attr_accessor :relation, :columns, :values

      def initialize
        @relation = nil
        @columns  = []
        @values   = []
      end
    end
  end
end
