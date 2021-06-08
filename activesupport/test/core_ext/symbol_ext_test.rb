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
end
