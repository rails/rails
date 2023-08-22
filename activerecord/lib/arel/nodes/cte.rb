# frozen_string_literal: true

module Arel # :nodoc: all
  module Nodes
    class Cte < Arel::Nodes::Binary
      alias :name :left
      alias :relation :right
      attr_reader :materialized

      def initialize(name, relation, materialized: nil)
        super(name, relation)
        @materialized = materialized
      end

      def hash
        [name, relation, materialized].hash
      end

      def eql?(other)
        self.class == other.class &&
          self.name == other.name &&
          self.relation == other.relation &&
          self.materialized == other.materialized
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
