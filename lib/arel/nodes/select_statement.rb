module Arel
  module Nodes
    class SelectStatement
      attr_reader :cores
      attr_accessor :limit, :orders, :lock

      def initialize cores = [SelectCore.new]
        @cores  = cores
        @orders = []
        @limit  = nil
        @lock   = nil
      end

      def initialize_copy other
        super
        @cores = @cores.clone
      end
    end
  end
end
