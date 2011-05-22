require 'abstract_unit'
require 'active_support/core_ext/integer'

class IntegerExtTest < Test::Unit::TestCase
  def test_ordinalize
    # These tests are mostly just to ensure that the ordinalize method exists.
    # Its results are tested comprehensively in the inflector test cases.
    assert_equal '1st', 1.ordinalize
    assert_equal '8th', 8.ordinalize
    1000000000000000000000000000000000000000000000000000000000000000000000.ordinalize
  end
end
