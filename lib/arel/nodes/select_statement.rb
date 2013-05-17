module Arel
  module Nodes
    class SelectStatement < Arel::Nodes::Node
      attr_reader :cores
      attr_accessor :limit, :orders, :lock, :offset, :with

      def initialize cores = [SelectCore.new]
        super()
        @cores          = cores
        @orders         = []
        @limit          = nil
        @lock           = nil
        @offset         = nil
        @with           = nil
      end

      def initialize_copy other
        super
        @cores  = @cores.map { |x| x.clone }
        @orders = @orders.map { |x| x.clone }
      end

      def hash
        [@cores, @orders, @limit, @lock, @offset, @with].hash
      end

      def eql? other
        self.class == other.class &&
          self.cores == other.cores &&
          self.orders == other.orders &&
          self.limit == other.limit &&
          self.lock == other.lock &&
          self.offset == other.offset &&
          self.with == other.with
      end
      alias :== :eql?
    end
  end
end
