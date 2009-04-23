require 'abstract_unit'
require 'active_support/core_ext/range'
require 'active_support/core_ext/date/conversions'

class RangeTest < Test::Unit::TestCase
  def test_to_s_from_dates
    date_range = Date.new(2005, 12, 10)..Date.new(2005, 12, 12)
    assert_equal "BETWEEN '2005-12-10' AND '2005-12-12'", date_range.to_s(:db)
  end

  def test_to_s_from_times
    date_range = Time.utc(2005, 12, 10, 15, 30)..Time.utc(2005, 12, 10, 17, 30)
    assert_equal "BETWEEN '2005-12-10 15:30:00' AND '2005-12-10 17:30:00'", date_range.to_s(:db)
  end

  def test_overlaps_last_inclusive
    assert((1..5).overlaps?(5..10))
  end

  def test_overlaps_last_exclusive
    assert !(1...5).overlaps?(5..10)
  end

  def test_overlaps_first_inclusive
    assert((5..10).overlaps?(1..5))
  end

  def test_overlaps_first_exclusive
    assert !(5..10).overlaps?(1...5)
  end

  def test_should_include_identical_inclusive
    assert((1..10).include?(1..10))
  end

  def test_should_include_identical_exclusive
    assert((1...10).include?(1...10))
  end

  def test_should_include_other_with_exlusive_end
    assert((1..10).include?(1...10))
  end

  def test_exclusive_end_should_not_include_identical_with_inclusive_end
    assert !(1...10).include?(1..10)
  end

  def test_should_not_include_overlapping_first
    assert !(2..8).include?(1..3)
  end

  def test_should_not_include_overlapping_last
    assert !(2..8).include?(5..9)
  end

  def test_blockless_step
    assert_equal [1,3,5,7,9], (1..10).step(2)
  end

  def test_original_step
    array = []
    (1..10).step(2) {|i| array << i }
    assert_equal [1,3,5,7,9], array
  end
end
