require 'action_dispatch/journey/nfa/dot'

module ActionDispatch
  module Journey # :nodoc:
    module NFA # :nodoc:
      class TransitionTable # :nodoc:
        include Journey::NFA::Dot

        attr_accessor :accepting
        attr_reader :memos

        def initialize
          @table     = Hash.new { |h,f| h[f] = {} }
          @memos     = {}
          @accepting = nil
          @inverted  = nil
        end

        def accepting?(state)
          accepting == state
        end

        def accepting_states
          [accepting]
        end

        def add_memo(idx, memo)
          @memos[idx] = memo
        end

        def memo(idx)
          @memos[idx]
        end

        def []=(i, f, s)
          @table[f][i] = s
        end

        def merge(left, right)
          @memos[right] = @memos.delete(left)
          @table[right] = @table.delete(left)
        end

        def states
          (@table.keys + @table.values.flat_map(&:keys)).uniq
        end

        # Returns a generalized transition graph with reduced states. The states
        # are reduced like a DFA, but the table must be simulated like an NFA.
        #
        # Edges of the GTG are regular expressions.
        def generalized_table
          gt       = GTG::TransitionTable.new
          marked   = {}
          state_id = Hash.new { |h,k| h[k] = h.length }
          alphabet = self.alphabet

          stack = [eclosure(0)]

          until stack.empty?
            state = stack.pop
            next if marked[state] || state.empty?

            marked[state] = true

            alphabet.each do |alpha|
              next_state = eclosure(following_states(state, alpha))
              next if next_state.empty?

              gt[state_id[state], state_id[next_state]] = alpha
              stack << next_state
            end
          end

          final_groups = state_id.keys.find_all { |s|
            s.sort.last == accepting
          }

          final_groups.each do |states|
            id = state_id[states]

            gt.add_accepting(id)
            save = states.find { |s|
              @memos.key?(s) && eclosure(s).sort.last == accepting
            }

            gt.add_memo(id, memo(save))
          end

          gt
        end

        # Returns set of NFA states to which there is a transition on ast symbol
        # +a+ from some state +s+ in +t+.
        def following_states(t, a)
          Array(t).flat_map { |s| inverted[s][a] }.uniq
        end

        # Returns set of NFA states to which there is a transition on ast symbol
        # +a+ from some state +s+ in +t+.
        def move(t, a)
          Array(t).map { |s|
            inverted[s].keys.compact.find_all { |sym|
              sym === a
            }.map { |sym| inverted[s][sym] }
          }.flatten.uniq
        end

        def alphabet
          inverted.values.flat_map(&:keys).compact.uniq.sort_by { |x| x.to_s }
        end

        # Returns a set of NFA states reachable from some NFA state +s+ in set
        # +t+ on nil-transitions alone.
        def eclosure(t)
          stack = Array(t)
          seen  = {}
          children = []

          until stack.empty?
            s = stack.pop
            next if seen[s]

            seen[s] = true
            children << s

            stack.concat(inverted[s][nil])
          end

          children.uniq
        end

        def transitions
          @table.flat_map { |to, hash|
            hash.map { |from, sym| [from, sym, to] }
          }
        end

        private

          def inverted
            return @inverted if @inverted

            @inverted = Hash.new { |h, from|
              h[from] = Hash.new { |j, s| j[s] = [] }
            }

            @table.each { |to, hash|
              hash.each { |from, sym|
                if sym
                  sym = Nodes::Symbol === sym ? sym.regexp : sym.left
                end

                @inverted[from][sym] << to
              }
            }

            @inverted
          end
      end
    end
  end
end
