require File.dirname(__FILE__) + '/../abstract_unit'

class SymbolTests < Test::Unit::TestCase
  def test_to_proc
    assert_equal %w(one two three), [:one, :two, :three].map(&:to_s)
    assert_equal(%w(one two three),
      {1 => "one", 2 => "two", 3 => "three"}.sort_by(&:first).map(&:last))
  end
end
