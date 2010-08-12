module Arel
  module Nodes
    class SqlLiteral
      attr_accessor :string

      def initialize string
        @string = string
      end
    end
  end
end
