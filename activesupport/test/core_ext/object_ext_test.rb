require 'abstract_unit'
require 'active_support/core_ext/object/metaclass'

class ObjectExtTest < Test::Unit::TestCase
  def test_tap_yields_and_returns_self
    foo = Object.new
    assert_equal foo, foo.tap { |x| assert_equal foo, x; :bar }
  end
end
