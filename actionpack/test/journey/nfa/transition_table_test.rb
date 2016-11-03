require "abstract_unit"

module ActionDispatch
  module Journey
    module NFA
      class TestTransitionTable < ActiveSupport::TestCase
        def setup
          @parser = Journey::Parser.new
        end

        def test_eclosure
          table = tt "/"
          assert_equal [0], table.eclosure(0)

          table = tt ":a|:b"
          assert_equal 3, table.eclosure(0).length

          table = tt "(:a|:b)"
          assert_equal 5, table.eclosure(0).length
          assert_equal 5, table.eclosure([0]).length
        end

        def test_following_states_one
          table = tt "/"

          assert_equal [1], table.following_states(0, "/")
          assert_equal [1], table.following_states([0], "/")
        end

        def test_following_states_group
          table  = tt "a|b"
          states = table.eclosure 0

          assert_equal 1, table.following_states(states, "a").length
          assert_equal 1, table.following_states(states, "b").length
        end

        def test_following_states_multi
          table  = tt "a|a"
          states = table.eclosure 0

          assert_equal 2, table.following_states(states, "a").length
          assert_equal 0, table.following_states(states, "b").length
        end

        def test_following_states_regexp
          table  = tt "a|:a"
          states = table.eclosure 0

          assert_equal 1, table.following_states(states, "a").length
          assert_equal 1, table.following_states(states, /[^\.\/\?]+/).length
          assert_equal 0, table.following_states(states, "b").length
        end

        def test_alphabet
          table = tt "a|:a"
          assert_equal [/[^\.\/\?]+/, "a"], table.alphabet

          table = tt "a|a"
          assert_equal ["a"], table.alphabet
        end

        private
          def tt(string)
            ast     = @parser.parse string
            builder = Builder.new ast
            builder.transition_table
          end
      end
    end
  end
end
