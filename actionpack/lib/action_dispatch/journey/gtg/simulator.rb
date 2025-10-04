# frozen_string_literal: true

# :markup: markdown

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
        STATIC_TOKENS = Array.new(64)
        STATIC_TOKENS[".".ord] = "."
        STATIC_TOKENS["/".ord] = "/"
        STATIC_TOKENS["?".ord] = "?"
        STATIC_TOKENS.freeze

        INITIAL_STATE = [0, nil].freeze

        attr_reader :tt

        def initialize(transition_table)
          @tt = transition_table
        end

        def memos(string)
          state = INITIAL_STATE

          pos = 0
          eos = string.bytesize

          while pos < eos
            start_index = pos
            pos += 1

            if (token = STATIC_TOKENS[string.getbyte(start_index)])
              state = tt.move(state, string, token, start_index, false)
            else
              while pos < eos && STATIC_TOKENS[string.getbyte(pos)].nil?
                pos += 1
              end

              token = string.byteslice(start_index, pos - start_index)
              state = tt.move(state, string, token, start_index, true)
            end
          end

          acceptance_states = []
          states_count = state.size
          i = 0
          while i < states_count
            if state[i + 1].nil?
              s = state[i]
              if tt.accepting?(s)
                acceptance_states.concat(tt.memo(s))
              end
            end
            i += 2
          end

          acceptance_states.empty? ? yield : acceptance_states
        end
      end
    end
  end
end
