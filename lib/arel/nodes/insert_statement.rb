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
        @columns = @columns.map { |o| o.clone }
        @values =  @values.map  { |o| o.clone }
      end
    end
  end
end
