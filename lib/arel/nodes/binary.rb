module Arel
  module Nodes
    class Binary < Arel::Nodes::Node
      attr_accessor :left, :right

      def initialize left, right
        @left  = left
        @right = right
      end
    end

    %w{
      Between
      NotEqual
      Assignment
      Or
      As
      GreaterThan
      GreaterThanOrEqual
      LessThan
      LessThanOrEqual
      Matches
    }.each do |name|
      const_set(name, Class.new(Binary))
    end
  end
end
