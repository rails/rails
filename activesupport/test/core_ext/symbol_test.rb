require 'test/unit'
require File.dirname(__FILE__) + '/../../lib/active_support/core_ext/symbol'

class SymbolTests < Test::Unit::TestCase
  def test_to_proc
    assert_equal %w(one two three), [:one, :two, :three].map(&:to_s)
  end
end
