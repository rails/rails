require "strscan"

module ActionDispatch
  module Journey # :nodoc:
    module GTG # :nodoc:
      class MatchData # :nodoc:
        attr_reader :memos

        def initialize(memos)
          @memos = memos
        end
      end

      class Simulator # :nodoc:
        attr_reader :tt

        def initialize(transition_table)
          @tt = transition_table
        end

        def simulate(string)
          ms = memos(string) { return }
          MatchData.new(ms)
        end

        alias :=~    :simulate
        alias :match :simulate

        def memos(string)
          input = StringScanner.new(string)
          state = [0]
          while sym = input.scan(%r([/.?]|[^/.?]+))
            state = tt.move(state, sym)
          end

          acceptance_states = state.find_all { |s|
            tt.accepting? s
          }

          return yield if acceptance_states.empty?

          acceptance_states.flat_map { |x| tt.memo(x) }.compact
        end
      end
    end
  end
end
