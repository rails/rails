# frozen_string_literal: true

module CustomCops
  # Enforces the use of `#assert_not` methods over `#refute` methods.
  #
  # @example
  #   # bad
  #   refute false
  #   refute_empty [1, 2, 3]
  #   refute_equal true, false
  #
  #   # good
  #   assert_not false
  #   assert_not_empty [1, 2, 3]
  #   assert_not_equal true, false
  #
  class RefuteNot < RuboCop::Cop::Cop
    MSG = "Prefer `%<assert_method>s` over `%<refute_method>s`"

    CORRECTIONS = {
      refute:             "assert_not",
      refute_empty:       "assert_not_empty",
      refute_equal:       "assert_not_equal",
      refute_in_delta:    "assert_not_in_delta",
      refute_in_epsilon:  "assert_not_in_epsilon",
      refute_includes:    "assert_not_includes",
      refute_instance_of: "assert_not_instance_of",
      refute_kind_of:     "assert_not_kind_of",
      refute_nil:         "assert_not_nil",
      refute_operator:    "assert_not_operator",
      refute_predicate:   "assert_not_predicate",
      refute_respond_to:  "assert_not_respond_to",
      refute_same:        "assert_not_same",
      refute_match:       "assert_no_match"
    }.freeze

    OFFENSIVE_METHODS = CORRECTIONS.keys.freeze

    def_node_matcher :offensive?, "(send nil? #offensive_method? ...)"

    def on_send(node)
      return unless offensive?(node)

      message = offense_message(node.method_name)
      add_offense(node, location: :selector, message: message)
    end

    def autocorrect(node)
      ->(corrector) do
        corrector.replace(
          node.loc.selector,
          CORRECTIONS[node.method_name]
        )
      end
    end

    private

      def offensive_method?(method_name)
        OFFENSIVE_METHODS.include?(method_name)
      end

      def offense_message(method_name)
        format(
          MSG,
          refute_method: method_name,
          assert_method: CORRECTIONS[method_name]
        )
      end
  end
end
