# frozen_string_literal: true

module Arel
  module Nodes
    class Values < Arel::Nodes::Binary
      alias :expressions :left
      alias :expressions= :left=
      alias :columns :right
      alias :columns= :right=

      def initialize(exprs, columns = [])
        super
      end
    end
  end
end
