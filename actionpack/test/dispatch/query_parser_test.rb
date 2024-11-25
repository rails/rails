# frozen_string_literal: true

require "abstract_unit"

class QueryParserTest < ActiveSupport::TestCase
  test "simple query string" do
    assert_equal [["foo", "bar"], ["baz", "quux"]], parsed_pairs("foo=bar&baz=quux")
  end

  test "query string with empty and missing values" do
    assert_equal [["foo", "bar"], ["empty", ""], ["missing", nil], ["baz", "quux"]], parsed_pairs("foo=bar&empty=&missing&baz=quux")
  end

  test "custom separator" do
    assert_equal [["foo", "bar"], ["baz", "quux"]], parsed_pairs("foo=bar;baz=quux", ";")
  end

  test "non-standard separator" do
    assert_equal [["foo", "bar"], ["baz", "quux"]], parsed_pairs("foo=bar/baz=quux", "/")
  end

  test "mixed separators" do
    assert_equal [["a", "aa"], ["b", "bb"], ["c", "cc"]], parsed_pairs("a=aa&b=bb;c=cc", "&;")
  end

  if ::Rack::RELEASE.start_with?("2.")
    test "(rack 2) defaults to mixed separators" do
      assert_deprecated(ActionDispatch.deprecator) do
        assert_equal [["a", "aa"], ["b", "bb"], ["c", "cc"]], parsed_pairs("a=aa&b=bb;c=cc")
      end
    end
  else
    test "(rack 3) defaults to ampersand separator only" do
      assert_equal [["a", "aa"], ["b", "bb;c=cc"]], parsed_pairs("a=aa&b=bb;c=cc")
    end
  end

  test "configured for strict separator" do
    previous_separator = ActionDispatch::QueryParser.strict_query_string_separator
    ActionDispatch::QueryParser.strict_query_string_separator = true
    assert_equal [["a", "aa"], ["b", "bb;c=cc"]], parsed_pairs("a=aa&b=bb;c=cc", "&")
  ensure
    ActionDispatch::QueryParser.strict_query_string_separator = previous_separator
  end

  test "configured for mixed separator" do
    previous_separator = ActionDispatch::QueryParser.strict_query_string_separator
    ActionDispatch::QueryParser.strict_query_string_separator = false
    assert_equal [["a", "aa"], ["b", "bb"], ["c", "cc"]], parsed_pairs("a=aa&b=bb;c=cc", "&;")
  ensure
    ActionDispatch::QueryParser.strict_query_string_separator = previous_separator
  end

  private
    def parsed_pairs(query, separator = nil)
      ActionDispatch::QueryParser.each_pair(query, separator).to_a
    end
end
