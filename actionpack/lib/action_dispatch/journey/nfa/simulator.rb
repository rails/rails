# frozen_string_literal: true

require "strscan"

module ActionDispatch
  module Journey # :nodoc:
    module NFA # :nodoc:
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
          input = StringScanner.new(string)
          state = tt.eclosure(0)
          until input.eos?
            sym   = input.scan(%r([/.?]|[^/.?]+))
            state = tt.eclosure(tt.move(state, sym))
          end

          acceptance_states = state.find_all { |s|
            tt.accepting?(tt.eclosure(s).sort.last)
          }

          return if acceptance_states.empty?

          memos = acceptance_states.flat_map { |x| tt.memo(x) }.compact

          MatchData.new(memos)
        end

        alias :=~    :simulate
        alias :match :simulate
      end
    end
  end
end
