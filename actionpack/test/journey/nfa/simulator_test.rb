require 'abstract_unit'

module ActionDispatch
  module Journey
    module NFA
      class TestSimulator < MiniTest::Unit::TestCase
        def test_simulate_simple
          sim = simulator_for ['/foo']
          assert_match sim, '/foo'
        end

        def test_simulate_simple_no_match
          sim = simulator_for ['/foo']
          refute_match sim, 'foo'
        end

        def test_simulate_simple_no_match_too_long
          sim = simulator_for ['/foo']
          refute_match sim, '/foo/bar'
        end

        def test_simulate_simple_no_match_wrong_string
          sim = simulator_for ['/foo']
          refute_match sim, '/bar'
        end

        def test_simulate_regex
          sim = simulator_for ['/:foo/bar']
          assert_match sim, '/bar/bar'
          assert_match sim, '/foo/bar'
        end

        def test_simulate_or
          sim = simulator_for ['/foo', '/bar']
          assert_match sim, '/bar'
          assert_match sim, '/foo'
          refute_match sim, '/baz'
        end

        def test_simulate_optional
          sim = simulator_for ['/foo(/bar)']
          assert_match sim, '/foo'
          assert_match sim, '/foo/bar'
          refute_match sim, '/foo/'
        end

        def test_matchdata_has_memos
          paths   = %w{ /foo /bar }
          parser  = Journey::Parser.new
          asts    = paths.map { |x|
            ast = parser.parse x
            ast.each { |n| n.memo = ast}
            ast
          }

          expected = asts.first

          builder = Builder.new Nodes::Or.new asts

          sim = Simulator.new builder.transition_table

          md = sim.match '/foo'
          assert_equal [expected], md.memos
        end

        def test_matchdata_memos_on_merge
          parser = Journey::Parser.new
          routes = [
            '/articles(.:format)',
            '/articles/new(.:format)',
            '/articles/:id/edit(.:format)',
            '/articles/:id(.:format)',
          ].map { |path|
            ast = parser.parse path
            ast.each { |n| n.memo = ast }
            ast
          }

          asts = routes.dup

          ast = Nodes::Or.new routes

          nfa   = Journey::NFA::Builder.new ast
          sim = Simulator.new nfa.transition_table
          md = sim.match '/articles'
          assert_equal [asts.first], md.memos
        end

        def simulator_for paths
          parser  = Journey::Parser.new
          asts    = paths.map { |x| parser.parse x }
          builder = Builder.new Nodes::Or.new asts
          Simulator.new builder.transition_table
        end
      end
    end
  end
end
