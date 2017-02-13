# frozen_string_literal: true
module Arel
  module Nodes
    class DeleteStatement < Arel::Nodes::Binary
      attr_accessor :limit

      alias :relation :left
      alias :relation= :left=
      alias :wheres :right
      alias :wheres= :right=

      def initialize relation = nil, wheres = []
        super
      end

      def initialize_copy other
        super
        @right = @right.clone
      end
    end
  end
end
