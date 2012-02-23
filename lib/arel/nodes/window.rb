module Arel
  module Nodes
    class Window < Arel::Nodes::Node
      include Arel::Expression
      attr_accessor :orders, :framing

      def initialize
        @orders = []
      end

      def order *expr
        # FIXME: We SHOULD NOT be converting these to SqlLiteral automatically
        @orders.concat expr.map { |x|
          String === x || Symbol === x ? Nodes::SqlLiteral.new(x.to_s) : x
        }
        self
      end

      def frame(expr)
        raise ArgumentError, "Window frame cannot be set more than once" if @frame
        @framing = expr
      end

      def rows(expr = nil)
        frame(Rows.new(expr))
      end

      def range(expr = nil)
        frame(Range.new(expr))
      end

      def initialize_copy other
        super
        @orders = @orders.map { |x| x.clone }
      end
    end

    class NamedWindow < Window
      attr_accessor :name

      def initialize name
        super()
        @name = name
      end

      def initialize_copy other
        super
        @name = other.name.clone
      end
    end

    class Rows < Unary
      def initialize(expr = nil)
        super(expr)
      end
    end

    class Range < Unary
      def initialize(expr = nil)
        super(expr)
      end
    end

    class CurrentRow < Arel::Nodes::Node; end

    class Preceding < Unary
      def initialize(expr = nil)
        super(expr)
      end
    end

    class Following < Unary
      def initialize(expr = nil)
        super(expr)
      end
    end
  end
end