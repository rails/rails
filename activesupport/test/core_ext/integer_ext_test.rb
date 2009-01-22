require 'abstract_unit'

class IntegerExtTest < Test::Unit::TestCase
  def test_even
    assert [ -2, 0, 2, 4 ].all? { |i| i.even? }
    assert ![ -1, 1, 3 ].all? { |i| i.even? }

    assert 22953686867719691230002707821868552601124472329079.odd?
    assert !22953686867719691230002707821868552601124472329079.even?
    assert 22953686867719691230002707821868552601124472329080.even?
    assert !22953686867719691230002707821868552601124472329080.odd?
  end

  def test_odd
    assert ![ -2, 0, 2, 4 ].all? { |i| i.odd? }
    assert [ -1, 1, 3 ].all? { |i| i.odd? }
    assert 1000000000000000000000000000000000000000000000000000000001.odd?
  end

  def test_multiple_of
    [ -7, 0, 7, 14 ].each { |i| assert i.multiple_of?(7) }
    [ -7, 7, 14 ].each { |i| assert ! i.multiple_of?(6) }
    # test with a prime
    assert !22953686867719691230002707821868552601124472329079.multiple_of?(2)
    assert !22953686867719691230002707821868552601124472329079.multiple_of?(3)
    assert !22953686867719691230002707821868552601124472329079.multiple_of?(5)
    assert !22953686867719691230002707821868552601124472329079.multiple_of?(7)
  end

  def test_ordinalize
    # These tests are mostly just to ensure that the ordinalize method exists.
    # Its results are tested comprehensively in the inflector test cases.
    assert_equal '1st', 1.ordinalize
    assert_equal '8th', 8.ordinalize
    1000000000000000000000000000000000000000000000000000000000000000000000.ordinalize
  end
end
