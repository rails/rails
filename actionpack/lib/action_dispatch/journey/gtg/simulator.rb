# frozen_string_literal: true

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
        INITIAL_STATE = [ [0, nil] ].freeze

        attr_reader :tt

        def initialize(transition_table)
          @tt = transition_table
        end

        def memos(string)
          input = StringScanner.new(string)
          state = INITIAL_STATE
          start_index = 0

          while sym = input.scan(%r([/.?]|[^/.?]+))
            end_index = start_index + sym.length

            state = tt.move(state, string, start_index, end_index)

            start_index = end_index
          end

          acceptance_states = state.each_with_object([]) do |s_d, memos|
            s, idx = s_d
            memos.concat(tt.memo(s)) if idx.nil? && tt.accepting?(s)
          end

          acceptance_states.empty? ? yield : acceptance_states
        end
      end
    end
  end
end
