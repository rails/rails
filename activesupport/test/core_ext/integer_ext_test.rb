require 'abstract_unit'
require 'active_support/core_ext/integer'

class IntegerExtTest < ActiveSupport::TestCase
  PRIME = 22953686867719691230002707821868552601124472329079

  def test_ordinalize
    # These tests are mostly just to ensure that the ordinalize method exists.
    # Its results are tested comprehensively in the inflector test cases.
    assert_equal '1st', 1.ordinalize
    assert_equal '8th', 8.ordinalize
  end

  def test_ordinal
    assert_equal 'st', 1.ordinal
    assert_equal 'th', 8.ordinal
  end
end
