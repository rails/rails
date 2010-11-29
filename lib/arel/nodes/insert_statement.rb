module Arel
  module Nodes
    class InsertStatement < Arel::Nodes::Node
      attr_accessor :relation, :columns, :values

      def initialize
        @relation = nil
        @columns  = []
        @values   = nil
      end

      def initialize_copy other
        super
        @columns = @columns.clone
        @values =  @values.clone if @values
      end
    end
  end
end
