require 'abstract_unit'
require 'active_support/time'
require 'active_support/core_ext/range'
require 'active_support/core_ext/numeric'

class RangeTest < ActiveSupport::TestCase
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

  def test_should_compare_identical_inclusive
    assert((1..10) === (1..10))
  end

  def test_should_compare_identical_exclusive
    assert((1...10) === (1...10))
  end

  def test_should_compare_other_with_exlusive_end
    assert((1..10) === (1...10))
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

  def test_should_include_identical_exclusive_with_floats
    assert((1.0...10.0).include?(1.0...10.0))
  end

  def test_cover_is_not_override
    range = (1..3)
    assert range.method(:include?) != range.method(:cover?)
  end

  def test_overlaps_on_time
    time_range_1 = Time.utc(2005, 12, 10, 15, 30)..Time.utc(2005, 12, 10, 17, 30)
    time_range_2 = Time.utc(2005, 12, 10, 17, 00)..Time.utc(2005, 12, 10, 18, 00)
    assert time_range_1.overlaps?(time_range_2)
  end

  def test_no_overlaps_on_time
    time_range_1 = Time.utc(2005, 12, 10, 15, 30)..Time.utc(2005, 12, 10, 17, 30)
    time_range_2 = Time.utc(2005, 12, 10, 17, 31)..Time.utc(2005, 12, 10, 18, 00)
    assert !time_range_1.overlaps?(time_range_2)
  end

  def test_infinite_bounds
    time_zone = ActiveSupport::TimeZone['Eastern Time (US & Canada)']

    time = Time.now
    date = Date.today
    datetime = DateTime.now
    twz = ActiveSupport::TimeWithZone.new(time, time_zone)

    infinity1 = Float::INFINITY
    infinity2 = BigDecimal.new('Infinity')

    [infinity1, infinity2].each do |infinity|
      [time, date, datetime, twz].each do |bound|
        [time, date, datetime, twz].each do |value|
          assert Range.new(bound, infinity).include?(value + 10.years)
          assert Range.new(-infinity, bound).include?(value - 10.years)

          assert !Range.new(bound, infinity).include?(value - 10.years)
          assert !Range.new(-infinity, bound).include?(value + 10.years)
        end
      end
    end
  end
end
