require 'abstract_unit'
require 'active_support/core_ext/struct'

class StructExt < ActiveSupport::TestCase
  def test_to_h
    x = Struct.new(:foo, :bar)
    z = x.new(1, 2)
    assert_equal({ foo: 1, bar: 2 }, z.to_h)
  end
end
