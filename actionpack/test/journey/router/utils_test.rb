require 'abstract_unit'

module ActionDispatch
  module Journey
    class Router
      class TestUtils < ActiveSupport::TestCase
        def test_path_escape
          assert_equal "a/b%20c+d", Utils.escape_path("a/b c+d")
        end

        def test_fragment_escape
          assert_equal "a/b%20c+d?e", Utils.escape_fragment("a/b c+d?e")
        end

        def test_uri_unescape
          assert_equal "a/b c+d", Utils.unescape_uri("a%2Fb%20c+d")
        end
      end
    end
  end
end
