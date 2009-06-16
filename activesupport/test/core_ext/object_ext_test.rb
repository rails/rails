require 'abstract_unit'

class ObjectExtTest < Test::Unit::TestCase
  def test_tap_yields_and_returns_self
    foo = Object.new
    assert_equal foo, foo.tap { |x| assert_equal foo, x; :bar }
  end

  def test_to_param
    foo = Object.new
    foo.class_eval("def to_s; 'foo'; end")
    assert_equal 'foo', foo.to_param
  end
end
