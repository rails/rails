module Arel
  module Nodes
    class MathOperation < Binary
      include Arel::Expressions
      include Arel::Predications
      include Arel::Math
    end

    class Multiplication < MathOperation; end
    class Division < MathOperation; end
    class Addition < MathOperation; end
    class Subtraction < MathOperation; end

  end
end