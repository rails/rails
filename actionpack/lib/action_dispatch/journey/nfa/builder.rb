require "action_dispatch/journey/nfa/transition_table"
require "action_dispatch/journey/gtg/transition_table"

module ActionDispatch
  module Journey # :nodoc:
    module NFA # :nodoc:
      class Visitor < Visitors::Visitor # :nodoc:
        def initialize(tt)
          @tt = tt
          @i  = -1
        end

        def visit_CAT(node)
          left  = visit(node.left)
          right = visit(node.right)

          @tt.merge(left.last, right.first)

          [left.first, right.last]
        end

        def visit_GROUP(node)
          from  = @i += 1
          left  = visit(node.left)
          to    = @i += 1

          @tt.accepting = to

          @tt[from, left.first] = nil
          @tt[left.last, to] = nil
          @tt[from, to] = nil

          [from, to]
        end

        def visit_OR(node)
          from = @i += 1
          children = node.children.map { |c| visit(c) }
          to   = @i += 1

          children.each do |child|
            @tt[from, child.first] = nil
            @tt[child.last, to]    = nil
          end

          @tt.accepting = to

          [from, to]
        end

        def terminal(node)
          from_i = @i += 1 # new state
          to_i   = @i += 1 # new state

          @tt[from_i, to_i] = node
          @tt.accepting = to_i
          @tt.add_memo(to_i, node.memo)

          [from_i, to_i]
        end
      end

      class Builder # :nodoc:
        def initialize(ast)
          @ast = ast
        end

        def transition_table
          tt = TransitionTable.new
          Visitor.new(tt).accept(@ast)
          tt
        end
      end
    end
  end
end
