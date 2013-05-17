module Arel
  module Nodes
    class InsertStatement < Arel::Nodes::Node
      attr_accessor :relation, :columns, :values

      def initialize
        super()
        @relation = nil
        @columns  = []
        @values   = nil
      end

      def initialize_copy other
        super
        @columns = @columns.clone
        @values =  @values.clone if @values
      end

      def hash
        [@relation, @columns, @values].hash
      end

      def eql? other
        self.class == other.class &&
          self.relation == other.relation &&
          self.columns == other.columns &&
          self.values == other.values
      end
      alias :== :eql?
    end
  end
end
