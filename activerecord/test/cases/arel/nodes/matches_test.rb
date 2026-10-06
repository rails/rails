# frozen_string_literal: true

require_relative "../helper"

module Arel
  module Nodes
    class TestMatches < Arel::Test
      def test_equality_with_same_ivars
        array = [Matches.new("foo", "bar", "!", true), Matches.new("foo", "bar", "!", true)]
        assert_equal 1, array.uniq.size
      end

      def test_inequality_with_different_escape
        array = [Matches.new("foo", "bar", "!"), Matches.new("foo", "bar")]
        assert_equal 2, array.uniq.size
      end

      def test_inequality_with_different_case_sensitivity
        array = [Matches.new("foo", "bar", nil, true), Matches.new("foo", "bar", nil, false)]
        assert_equal 2, array.uniq.size
      end
    end

    class TestRegexp < Arel::Test
      def test_equality_with_same_ivars
        array = [Regexp.new("foo", "bar", true), Regexp.new("foo", "bar", true)]
        assert_equal 1, array.uniq.size
      end

      def test_inequality_with_different_case_sensitivity
        array = [Regexp.new("foo", "bar", true), Regexp.new("foo", "bar", false)]
        assert_equal 2, array.uniq.size
      end
    end
  end
end
