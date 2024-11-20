# frozen_string_literal: true

# :markup: markdown

require "action_dispatch/journey/gtg/transition_table"

module ActionDispatch
  module Journey # :nodoc:
    module GTG # :nodoc:
      class Builder # :nodoc:
        DUMMY_END_NODE = Nodes::Dummy.new

        attr_reader :root, :ast, :endpoints

        def initialize(root)
          @root      = root
          @ast       = Nodes::Cat.new root, DUMMY_END_NODE
          @followpos = build_followpos
        end

        def transition_table
          dtrans   = TransitionTable.new
          marked   = {}.compare_by_identity
          state_id = Hash.new { |h, k| h[k] = h.length }.compare_by_identity
          dstates  = [firstpos(root)]

          until dstates.empty?
            s = dstates.shift
            next if marked[s]
            marked[s] = true # mark s

            s.group_by { |state| symbol(state) }.each do |sym, ps|
              u = ps.flat_map { |l| @followpos[l] }.uniq
              next if u.empty?

              from = state_id[s]

              if u.all? { |pos| pos == DUMMY_END_NODE }
                to = state_id[Object.new]
                dtrans[from, to] = sym
                dtrans.add_accepting(to)

                ps.each { |state| dtrans.add_memo(to, state.memo) }
              else
                to = state_id[u]
                dtrans[from, to] = sym

                if u.include?(DUMMY_END_NODE)
                  ps.each do |state|
                    if @followpos[state].include?(DUMMY_END_NODE)
                      dtrans.add_memo(to, state.memo)
                    end
                  end

                  dtrans.add_accepting(to)
                end
              end

              dstates << u
            end
          end

          dtrans
        end

        def nullable?(node)
          case node
          when Nodes::Group
            true
          when Nodes::Star
            # the default star regex is /(.+)/ which is NOT nullable but since different
            # constraints can be provided we must actually check if this is the case or not.
            node.regexp.match?("")
          when Nodes::Or
            node.children.any? { |c| nullable?(c) }
          when Nodes::Cat
            nullable?(node.left) && nullable?(node.right)
          when Nodes::Terminal
            !node.left
          when Nodes::Unary
            nullable?(node.left)
          else
            raise ArgumentError, "unknown nullable: %s" % node.class.name
          end
        end

        def firstpos(node)
          case node
          when Nodes::Star
            firstpos(node.left)
          when Nodes::Cat
            if nullable?(node.left)
              firstpos(node.left) | firstpos(node.right)
            else
              firstpos(node.left)
            end
          when Nodes::Or
            node.children.flat_map { |c| firstpos(c) }.tap(&:uniq!)
          when Nodes::Unary
            firstpos(node.left)
          when Nodes::Terminal
            nullable?(node) ? [] : [node]
          else
            raise ArgumentError, "unknown firstpos: %s" % node.class.name
          end
        end

        def lastpos(node)
          case node
          when Nodes::Star
            lastpos(node.left)
          when Nodes::Or
            node.children.flat_map { |c| lastpos(c) }.tap(&:uniq!)
          when Nodes::Cat
            if nullable?(node.right)
              lastpos(node.left) | lastpos(node.right)
            else
              lastpos(node.right)
            end
          when Nodes::Terminal
            nullable?(node) ? [] : [node]
          when Nodes::Unary
            lastpos(node.left)
          else
            raise ArgumentError, "unknown lastpos: %s" % node.class.name
          end
        end

        private
          def build_followpos
            table = Hash.new { |h, k| h[k] = [] }.compare_by_identity
            @ast.each do |n|
              case n
              when Nodes::Cat
                lastpos(n.left).each do |i|
                  table[i] += firstpos(n.right)
                end
              end
            end
            table
          end

          def symbol(edge)
            edge.symbol? ? edge.regexp : edge.left
          end
      end
    end
  end
end
