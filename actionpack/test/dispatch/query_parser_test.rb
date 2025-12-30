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

  test "defaults to ampersand separator only" do
    assert_equal [["a", "aa"], ["b", "bb;c=cc"]], parsed_pairs("a=aa&b=bb;c=cc")
  end

  private
    def parsed_pairs(query, separator = nil)
      ActionDispatch::QueryParser.each_pair(query, separator).to_a
    end
end
