module Arel
  module Nodes
    class InsertStatement
      attr_accessor :relation, :columns, :values

      def initialize
        @relation = nil
        @columns  = []
        @values   = []
      end

      def initialize_copy other
        super
        @columns = @columns.clone
        @values =  @values.clone
      end
    end
  end
end
