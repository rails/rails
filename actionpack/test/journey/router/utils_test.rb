# frozen_string_literal: true

require "abstract_unit"

module ActionDispatch
  module Journey
    class Router
      class TestUtils < ActiveSupport::TestCase
        def test_path_escape
          assert_equal "a/b%20c+d%25", Utils.escape_path("a/b c+d%")
        end

        def test_segment_escape
          assert_equal "a%2Fb%20c+d%25", Utils.escape_segment("a/b c+d%")
        end

        def test_fragment_escape
          assert_equal "a/b%20c+d%25?e", Utils.escape_fragment("a/b c+d%?e")
        end

        def test_uri_unescape
          assert_equal "a/b c+d", Utils.unescape_uri("a%2Fb%20c+d")
        end

        def test_uri_unescape_with_utf8_string
          assert_equal "Šašinková", Utils.unescape_uri("%C5%A0a%C5%A1inkov%C3%A1".dup.force_encoding(Encoding::US_ASCII))
        end

        def test_normalize_path_not_greedy
          assert_equal "/foo%20bar%20baz", Utils.normalize_path("/foo%20bar%20baz")
        end

        def test_normalize_path_uppercase
          assert_equal "/foo%AAbar%AAbaz", Utils.normalize_path("/foo%aabar%aabaz")
        end

        def test_normalize_path_maintains_string_encoding
          path = "/foo%AAbar%AAbaz".b
          assert_equal Encoding::ASCII_8BIT, Utils.normalize_path(path).encoding
        end

        def test_normalize_path_with_nil
          assert_equal "/", Utils.normalize_path(nil)
        end
      end
    end
  end
end
