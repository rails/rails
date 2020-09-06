# frozen_string_literal: true

require 'strscan'

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
        INITIAL_STATE = [0].freeze

        attr_reader :tt

        def initialize(transition_table)
          @tt = transition_table
        end

        def memos(string)
          input = StringScanner.new(string)
          state = INITIAL_STATE

          while sym = input.scan(%r([/.?]|[^/.?]+))
            state = tt.move(state, sym)
          end

          acceptance_states = state.each_with_object([]) do |s, memos|
            memos.concat(tt.memo(s)) if tt.accepting?(s)
          end

          acceptance_states.empty? ? yield : acceptance_states
        end
      end
    end
  end
end
