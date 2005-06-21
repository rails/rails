require 'test/unit'
require File.dirname(__FILE__) + '/../../lib/active_support/core_ext/fixnum'

class FixnumExtTest < Test::Unit::TestCase
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
  end
  
  def test_multiple_of
    assert [ -7, 0, 7, 14 ].all? { |i| i.multiple_of? 7 }
    assert ![ -7, 0, 7, 14 ].all? { |i| i.multiple_of? 6 }
    # test with a prime
    assert !22953686867719691230002707821868552601124472329079.multiple_of?(2)
    assert !22953686867719691230002707821868552601124472329079.multiple_of?(3)
    assert !22953686867719691230002707821868552601124472329079.multiple_of?(5)
    assert !22953686867719691230002707821868552601124472329079.multiple_of?(7)
  end
end
