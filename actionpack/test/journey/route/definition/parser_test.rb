require 'abstract_unit'

module ActionDispatch
  module Journey
    module Definition
      class TestParser < ActiveSupport::TestCase
        def setup
          @parser = Parser.new
        end

        def test_slash
          assert_equal :SLASH, @parser.parse('/').type
          assert_round_trip '/'
        end

        def test_segment
          assert_round_trip '/foo'
        end

        def test_segments
          assert_round_trip '/foo/bar'
        end

        def test_segment_symbol
          assert_round_trip '/foo/:id'
        end

        def test_symbol
          assert_round_trip '/:foo'
        end

        def test_group
          assert_round_trip '(/:foo)'
        end

        def test_groups
          assert_round_trip '(/:foo)(/:bar)'
        end

        def test_nested_groups
          assert_round_trip '(/:foo(/:bar))'
        end

        def test_dot_symbol
          assert_round_trip('.:format')
        end

        def test_dot_literal
          assert_round_trip('.xml')
        end

        def test_segment_dot
          assert_round_trip('/foo.:bar')
        end

        def test_segment_group_dot
          assert_round_trip('/foo(.:bar)')
        end

        def test_segment_group
          assert_round_trip('/foo(/:action)')
        end

        def test_segment_groups
          assert_round_trip('/foo(/:action)(/:bar)')
        end

        def test_segment_nested_groups
          assert_round_trip('/foo(/:action(/:bar))')
        end

        def test_group_followed_by_path
          assert_round_trip('/foo(/:action)/:bar')
        end

        def test_star
          assert_round_trip('*foo')
          assert_round_trip('/*foo')
          assert_round_trip('/bar/*foo')
          assert_round_trip('/bar/(*foo)')
        end

        def test_or
          assert_round_trip('a|b')
          assert_round_trip('a|b|c')
          assert_round_trip('(a|b)|c')
          assert_round_trip('a|(b|c)')
          assert_round_trip('*a|(b|c)')
          assert_round_trip('*a|:b|c')
        end

        def test_arbitrary
          assert_round_trip('/bar/*foo#')
        end

        def test_literal_dot_paren
          assert_round_trip "/sprockets.js(.:format)"
        end

        def test_groups_with_dot
          assert_round_trip "/(:locale)(.:format)"
        end

        def assert_round_trip str
          assert_equal str, @parser.parse(str).to_s
        end
      end
    end
  end
end
