# frozen_string_literal: true

require_relative "../abstract_unit"
require "active_support/core_ext/symbol"

class SymbolStartsEndsWithTest < ActiveSupport::TestCase
  def test_starts_ends_with_alias
    s = :hello
    assert s.starts_with?("h")
    assert s.starts_with?("hel")
    assert_not s.starts_with?("el")
    assert s.starts_with?("he", "lo")
    assert_not s.starts_with?("el", "lo")

    assert s.ends_with?("o")
    assert s.ends_with?("lo")
    assert_not s.ends_with?("el")
    assert s.ends_with?("he", "lo")
    assert_not s.ends_with?("he", "ll")
  end

  def test_to_s_returns_the_interned_frozen_name
    assert_predicate :foo.to_s, :frozen?
    assert_same :foo.name, :foo.to_s
    assert_equal "foo", :foo.to_s
    assert_equal "xfoo", "x#{:foo}"
  end
end
