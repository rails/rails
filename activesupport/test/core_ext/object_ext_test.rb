require 'abstract_unit'

class ObjectExtTest < Test::Unit::TestCase
  def test_tap_yields_and_returns_self
    foo = Object.new
    assert_equal foo, foo.tap { |x| assert_equal foo, x; :bar }
  end
end
