require 'test/unit'
require File.dirname(__FILE__) + '/../../lib/active_support/core_ext/fixnum'

class FixnumExtTest < Test::Unit::TestCase
  def test_even
    assert [ -2, 0, 2, 4 ].all? { |i| i.even? }
    assert ![ -1, 1, 3 ].all? { |i| i.even? }
  end

  def test_odd
    assert ![ -2, 0, 2, 4 ].all? { |i| i.odd? }
    assert [ -1, 1, 3 ].all? { |i| i.odd? }
  end
end
