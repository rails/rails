module Arel
  module Nodes
    class SelectStatement
      attr_reader :cores
      attr_accessor :limit

      def initialize cores = [SelectCore.new]
        @cores = cores
        @limit = nil
      end
    end
  end
end
