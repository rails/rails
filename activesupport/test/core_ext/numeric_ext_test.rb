require 'test/unit'
require File.dirname(__FILE__) + '/../../lib/core_ext/numeric'

class NumericExtTimeTest < Test::Unit::TestCase
  def setup
    @now = Time.now
    @seconds = {
      1.minute   => 60,
      10.minutes => 600,
      1.hour + 15.minutes => 4500,
      2.days + 4.hours + 30.minutes => 189000,
      5.years + 1.month + 1.fortnight => 161481600
    }
  end

  def test_time_units
    @seconds.each do |actual, expected|
      assert_equal expected, actual
      assert_equal expected.since(@now),  @now + actual
      assert_equal expected.until(@now),  @now - actual
    end
  end
end

class NumericExtSizeTest < Test::Unit::TestCase

  def test_unit_in_terms_of_another
    relationships = {
        1024.kilobytes =>   1.megabyte,
      3584.0.kilobytes => 3.5.megabytes,
      3584.0.megabytes => 3.5.gigabytes,
      1.kilobyte ** 4  =>   1.terabyte,
      1024.kilobytes + 2.megabytes =>   3.megabytes,
                   2.gigabytes / 4 => 512.megabytes,
      256.megabytes * 20 + 5.gigabytes => 10.gigabytes
    }

    relationships.each do |left, right|
      assert_equal right, left
    end
  end
end
