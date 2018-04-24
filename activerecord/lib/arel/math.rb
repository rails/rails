# frozen_string_literal: true

module Arel # :nodoc: all
  module Math
    def *(other)
      Arel::Nodes::Multiplication.new(self, other)
    end

    def +(other)
      Arel::Nodes::Grouping.new(Arel::Nodes::Addition.new(self, other))
    end

    def -(other)
      Arel::Nodes::Grouping.new(Arel::Nodes::Subtraction.new(self, other))
    end

    def /(other)
      Arel::Nodes::Division.new(self, other)
    end

    def &(other)
      Arel::Nodes::Grouping.new(Arel::Nodes::BitwiseAnd.new(self, other))
    end

    def |(other)
      Arel::Nodes::Grouping.new(Arel::Nodes::BitwiseOr.new(self, other))
    end

    def ^(other)
      Arel::Nodes::Grouping.new(Arel::Nodes::BitwiseXor.new(self, other))
    end

    def <<(other)
      Arel::Nodes::Grouping.new(Arel::Nodes::BitwiseShiftLeft.new(self, other))
    end

    def >>(other)
      Arel::Nodes::Grouping.new(Arel::Nodes::BitwiseShiftRight.new(self, other))
    end

    def ~@
      Arel::Nodes::BitwiseNot.new(self)
    end
  end
end
