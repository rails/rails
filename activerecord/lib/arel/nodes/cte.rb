# frozen_string_literal: true

module Arel # :nodoc: all
  module Nodes
    class Cte < Arel::Nodes::Binary
      alias :name :left
      alias :relation :right
      attr_reader :materialized, :cycle

      def initialize(name, relation, materialized: nil, cycle: nil)
        super(name, relation)
        @materialized = materialized
        @cycle = cycle
      end

      def hash
        [name, relation, materialized, cycle].hash
      end

      def eql?(other)
        self.class == other.class &&
          self.name == other.name &&
          self.relation == other.relation &&
          self.materialized == other.materialized &&
          self.cycle == other.cycle
      end
      alias :== :eql?

      def to_cte
        self
      end

      def to_table
        Arel::Table.new(name)
      end
    end
  end
end
