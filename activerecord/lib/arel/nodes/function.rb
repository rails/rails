# frozen_string_literal: true

module Arel # :nodoc: all
  module Nodes
    class Function < Arel::Nodes::NodeExpression
      include Arel::WindowPredications
      include Arel::FilterPredications

      attr_accessor :expressions, :distinct

      def initialize(expr)
        super()
        @expressions = expr
        @distinct    = false
      end

      def hash
        [@expressions, @distinct].hash
      end

      def eql?(other)
        self.class == other.class &&
          self.expressions == other.expressions &&
          self.distinct == other.distinct
      end
      alias :== :eql?
    end

    %w{
      Sum
      Exists
      Max
      Min
      Avg
    }.each do |name|
      const_set(name, Class.new(Function))
    end
  end
end
