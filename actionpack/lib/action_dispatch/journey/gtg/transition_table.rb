# frozen_string_literal: true

require "action_dispatch/journey/nfa/dot"

module ActionDispatch
  module Journey # :nodoc:
    module GTG # :nodoc:
      class TransitionTable # :nodoc:
        include Journey::NFA::Dot

        attr_reader :memos

        DEFAULT_EXP = /[^.\/?]+/
        DEFAULT_EXP_ANCHORED = Regexp.new(/\A#{DEFAULT_EXP}\Z/)

        def initialize
          @stdparam_states = {}
          @regexp_states   = {}
          @string_states   = {}
          @accepting       = {}
          @memos           = Hash.new { |h, k| h[k] = [] }
        end

        def add_accepting(state)
          @accepting[state] = true
        end

        def accepting_states
          @accepting.keys
        end

        def accepting?(state)
          @accepting[state]
        end

        def add_memo(idx, memo)
          @memos[idx] << memo
        end

        def memo(idx)
          @memos[idx]
        end

        def eclosure(t)
          Array(t)
        end

        def move(t, full_string, start_index, end_index)
          return [] if t.empty?

          next_states = Set.new

          tok = full_string.slice(start_index, end_index - start_index)
          token_matches_default_component = DEFAULT_EXP_ANCHORED.match?(tok)

          t.each { |s, previous_start|
            # In the simple case of a "default" param regex do this fast-path
            # and add all next states.
            if previous_start.nil? && token_matches_default_component && states = @stdparam_states[s]
              states.each { |re, v| next_states.add [v, nil].freeze if !v.nil? }
            end

            # For regexes that aren't the "default" style, they may potentially
            # not be terminated by the first "token" [./?], so we need to continue
            # to attempt to match this regexp as well as any successful paths that
            # continue out of it. both paths could be valid.
            if states = @regexp_states[s]
              states.each { |re, v|
                next if v.nil?

                slice_start = if previous_start.nil?
                  start_index
                else
                  previous_start
                end

                # if we match, we can try moving past this
                slice_length = end_index - slice_start
                next_states.add [v, nil].freeze if re.match?(full_string.slice(slice_start, slice_length))
                # and regardless, we must continue accepting tokens.
                # we need to remember where we started as well so we can take bigger slices.
                next_states.add [s, slice_start].freeze
              }
            end

            if previous_start.nil? && states = @string_states[s]
              next_states.add [states[tok], nil].freeze unless states[tok].nil?
            end
          }

          next_states
        end

        def as_json(options = nil)
          simple_regexp = Hash.new { |h, k| h[k] = {} }

          @regexp_states.each do |from, hash|
            hash.each do |re, to|
              simple_regexp[from][re.source] = to
            end
          end

          {
            regexp_states:   simple_regexp,
            string_states:   @string_states,
            stdparam_states: @stdparam_states,
            accepting:       @accepting
          }
        end

        def to_svg
          svg = IO.popen("dot -Tsvg", "w+") { |f|
            f.write(to_dot)
            f.close_write
            f.readlines
          }
          3.times { svg.shift }
          svg.join.sub(/width="[^"]*"/, "").sub(/height="[^"]*"/, "")
        end

        def visualizer(paths, title = "FSM")
          viz_dir   = File.join __dir__, "..", "visualizer"
          fsm_js    = File.read File.join(viz_dir, "fsm.js")
          fsm_css   = File.read File.join(viz_dir, "fsm.css")
          erb       = File.read File.join(viz_dir, "index.html.erb")
          states    = "function tt() { return #{to_json}; }"

          fun_routes = paths.sample(3).map do |ast|
            ast.map { |n|
              case n
              when Nodes::Symbol
                case n.left
                when ":id" then rand(100).to_s
                when ":format" then %w{ xml json }.sample
                else
                  "omg"
                end
              when Nodes::Terminal then n.symbol
              else
                nil
              end
            }.compact.join
          end

          stylesheets = [fsm_css]
          svg         = to_svg
          javascripts = [states, fsm_js]

          fun_routes  = fun_routes
          stylesheets = stylesheets
          svg         = svg
          javascripts = javascripts

          require "erb"
          template = ERB.new erb
          template.result(binding)
        end

        def []=(from, to, sym)
          to_mappings = states_hash_for(sym)[from] ||= {}
          if sym.is_a? Regexp
            # we must match the whole string to a token boundary
            sym = Regexp.new(/\A#{sym}\Z/)
          end
          to_mappings[sym] = to
        end

        def states
          ss = @string_states.keys + @string_states.values.flat_map(&:values)
          ps = @stdparam_states.keys + @stdparam_states.values.flat_map(&:values)
          rs = @regexp_states.keys + @regexp_states.values.flat_map(&:values)
          (ss + ps + rs).uniq
        end

        def transitions
          @string_states.flat_map { |from, hash|
            hash.map { |s, to| [from, s, to] }
          } + @stdparam_states.flat_map { |from, hash|
            hash.map { |s, to| [from, s, to] }
          } + @regexp_states.flat_map { |from, hash|
            hash.map { |s, to| [from, s, to] }
          }
        end

        private
          def states_hash_for(sym)
            case sym
            when String
              @string_states
            when Regexp
              if sym == DEFAULT_EXP
                @stdparam_states
              else
                @regexp_states
              end
            else
              raise ArgumentError, "unknown symbol: %s" % sym.class
            end
          end
      end
    end
  end
end
