# frozen_string_literal: true

module Arel # :nodoc: all
  module Nodes
    class Equality < Arel::Nodes::Binary
      def operator; :== end
      alias :operand1 :left
      alias :operand2 :right
    end

    %w{
      IsDistinctFrom
      IsNotDistinctFrom
    }.each do |name|
      const_set name, Class.new(Equality)
    end
  end
end
