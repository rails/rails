module Arel
  module Nodes
    class SelectStatement < Arel::Nodes::Node
      attr_reader :cores
      attr_accessor :limit, :orders, :lock, :offset

      def initialize cores = [SelectCore.new]
        @cores  = cores
        @orders = []
        @limit  = nil
        @lock   = nil
        @offset = nil
      end

      def initialize_copy other
        super
        @cores  = @cores.map { |x| x.clone }
        @orders = @orders.map { |x| x.clone }
      end
    end
  end
end
