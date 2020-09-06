# frozen_string_literal: true

require 'abstract_unit'
require 'active_support/json/decoding'

module ActionDispatch
  module Journey
    module GTG
      class TestGeneralizedTable < ActiveSupport::TestCase
        def test_to_json
          table = tt %w{
            /articles(.:format)
            /articles/new(.:format)
            /articles/:id/edit(.:format)
            /articles/:id(.:format)
          }

          json = ActiveSupport::JSON.decode table.to_json
          assert json['regexp_states']
          assert json['string_states']
          assert json['accepting']
        end

        if system('dot -V', 2 => File::NULL)
          def test_to_svg
            table = tt %w{
              /articles(.:format)
              /articles/new(.:format)
              /articles/:id/edit(.:format)
              /articles/:id(.:format)
            }
            svg = table.to_svg
            assert svg
            assert_no_match(/DOCTYPE/, svg)
          end
        end

        def test_simulate_gt
          sim = simulator_for ['/foo', '/bar']
          assert_match_route sim, '/foo'
        end

        def test_simulate_gt_regexp
          sim = simulator_for [':foo']
          assert_match_route sim, 'foo'
        end

        def test_simulate_gt_regexp_mix
          sim = simulator_for ['/get', '/:method/foo']
          assert_match_route sim, '/get'
          assert_match_route sim, '/get/foo'
        end

        def test_simulate_optional
          sim = simulator_for ['/foo(/bar)']
          assert_match_route sim, '/foo'
          assert_match_route sim, '/foo/bar'
          assert_no_match_route sim, '/foo/'
        end

        def test_match_data
          path_asts = asts %w{ /get /:method/foo }
          paths     = path_asts.dup

          builder = GTG::Builder.new Nodes::Or.new path_asts
          tt = builder.transition_table

          sim = GTG::Simulator.new tt

          memos = sim.memos '/get'
          assert_equal [paths.first], memos

          memos = sim.memos '/get/foo'
          assert_equal [paths.last], memos
        end

        def test_match_data_ambiguous
          path_asts = asts %w{
            /articles(.:format)
            /articles/new(.:format)
            /articles/:id/edit(.:format)
            /articles/:id(.:format)
          }

          paths = path_asts.dup
          ast   = Nodes::Or.new path_asts

          builder = GTG::Builder.new ast
          sim     = GTG::Simulator.new builder.transition_table

          memos = sim.memos '/articles/new'
          assert_equal [paths[1], paths[3]], memos
        end

        private
          def asts(paths)
            parser = Journey::Parser.new
            paths.map { |x|
              ast = parser.parse x
              ast.each { |n| n.memo = ast }
              ast
            }
          end

          def tt(paths)
            x = asts paths
            builder = GTG::Builder.new Nodes::Or.new x
            builder.transition_table
          end

          def simulator_for(paths)
            GTG::Simulator.new tt(paths)
          end

          def assert_match_route(simulator, path)
            assert simulator.memos(path), "Simulator should match #{path}."
          end

          def assert_no_match_route(simulator, path)
            assert_not simulator.memos(path) { nil }, "Simulator should not match #{path}."
          end
      end
    end
  end
end
