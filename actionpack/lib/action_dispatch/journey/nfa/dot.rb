# frozen_string_literal: true

module ActionDispatch
  module Journey # :nodoc:
    module NFA # :nodoc:
      module Dot # :nodoc:
        def to_dot
          edges = transitions.map { |from, sym, to|
            "  #{from} -> #{to} [label=\"#{sym || 'ε'}\"];"
          }

          <<-eodot
digraph nfa {
  rankdir=LR;
  node [shape = doublecircle];
  #{accepting_states.join ' '};
  node [shape = circle];
#{edges.join "\n"}
}
          eodot
        end
      end
    end
  end
end
