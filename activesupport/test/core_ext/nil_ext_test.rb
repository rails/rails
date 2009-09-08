require 'abstract_unit'
require 'active_support/core_ext/nil/conversions'

class NilExtAccessTests < Test::Unit::TestCase
  def test_to_param
    assert_nil nil.to_param
  end
end
