module Arel
  module Nodes
    class SelectStatement
      attr_reader :cores
      attr_accessor :limit, :orders

      def initialize cores = [SelectCore.new]
        @cores  = cores
        @orders = []
        @limit  = nil
      end

      def initialize_copy other
        super
        @cores = @cores.clone
      end
    end
  end
end
