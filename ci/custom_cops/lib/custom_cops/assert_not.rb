# frozen_string_literal: true

module CustomCops
  # Enforces the use of `assert_not` over `assert !`.
  #
  # @example
  #   # bad
  #   assert !x
  #   assert ! x
  #
  #   # good
  #   assert_not x
  #
  class AssertNot < RuboCop::Cop::Cop
    MSG = "Prefer `assert_not` over `assert !`"

    def_node_matcher :offensive?, "(send nil? :assert (send ... :!) ...)"

    def on_send(node)
      add_offense(node) if offensive?(node)
    end

    def autocorrect(node)
      expression = node.loc.expression

      ->(corrector) do
        corrector.replace(
          expression,
          corrected_source(expression.source)
        )
      end
    end

    private

      def corrected_source(source)
        source.gsub(/^assert(\(| ) *! */, "assert_not\\1")
      end
  end
end
