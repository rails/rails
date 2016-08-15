require "abstract_unit"

module ActionDispatch
  module Journey
    module GTG
      class TestBuilder < ActiveSupport::TestCase
        def test_following_states_multi
          table  = tt ["a|a"]
          assert_equal 1, table.move([0], "a").length
        end

        def test_following_states_multi_regexp
          table  = tt [":a|b"]
          assert_equal 1, table.move([0], "fooo").length
          assert_equal 2, table.move([0], "b").length
        end

        def test_multi_path
          table  = tt ["/:a/d", "/b/c"]

          [
            [1, "/"],
            [2, "b"],
            [2, "/"],
            [1, "c"],
          ].inject([0]) { |state, (exp, sym)|
            new = table.move(state, sym)
            assert_equal exp, new.length
            new
          }
        end

        def test_match_data_ambiguous
          table = tt %w{
            /articles(.:format)
            /articles/new(.:format)
            /articles/:id/edit(.:format)
            /articles/:id(.:format)
          }

          sim     = NFA::Simulator.new table

          match = sim.match "/articles/new"
          assert_equal 2, match.memos.length
        end

        ##
        # Identical Routes may have different restrictions.
        def test_match_same_paths
          table = tt %w{
            /articles/new(.:format)
            /articles/new(.:format)
          }

          sim     = NFA::Simulator.new table

          match = sim.match "/articles/new"
          assert_equal 2, match.memos.length
        end

        private
          def ast(strings)
            parser = Journey::Parser.new
            asts   = strings.map { |string|
              memo = Object.new
              ast  = parser.parse string
              ast.each { |n| n.memo = memo }
              ast
            }
            Nodes::Or.new asts
          end

          def tt(strings)
            Builder.new(ast(strings)).transition_table
          end
      end
    end
  end
end
