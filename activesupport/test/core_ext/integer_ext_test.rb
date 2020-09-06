# frozen_string_literal: true

require_relative '../abstract_unit'
require 'active_support/core_ext/integer'

class IntegerExtTest < ActiveSupport::TestCase
  PRIME = 22953686867719691230002707821868552601124472329079

  def test_multiple_of
    [ -7, 0, 7, 14 ].each { |i| assert i.multiple_of?(7) }
    [ -7, 7, 14 ].each { |i| assert_not i.multiple_of?(6) }

    # test the 0 edge case
    assert 0.multiple_of?(0)
    assert_not 5.multiple_of?(0)

    # test with a prime
    [2, 3, 5, 7].each { |i| assert_not PRIME.multiple_of?(i) }
  end

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
