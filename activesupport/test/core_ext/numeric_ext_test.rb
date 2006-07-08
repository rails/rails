require File.dirname(__FILE__) + '/../abstract_unit'

class NumericExtTimeTest < Test::Unit::TestCase
  def setup
    @now = Time.now
    @seconds = {
      1.minute   => 60,
      10.minutes => 600,
      1.hour + 15.minutes => 4500,
      2.days + 4.hours + 30.minutes => 189000,
      5.years + 1.month + 1.fortnight => 161589600
    }
  end

  def test_units
    @seconds.each do |actual, expected|
      assert_equal expected, actual
    end
  end

  def test_intervals
    @seconds.values.each do |seconds|
      assert_equal seconds.since(@now), @now + seconds
      assert_equal seconds.until(@now), @now - seconds
    end
  end

  # Test intervals based from Time.now
  def test_now
    @seconds.values.each do |seconds|
      now = Time.now
      assert seconds.ago >= now - seconds
      now = Time.now
      assert seconds.from_now >= now + seconds
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
      256.megabytes * 20 + 5.gigabytes => 10.gigabytes,
      1.kilobyte ** 5 => 1.petabyte,
      1.kilobyte ** 6 => 1.exabyte
    }

    relationships.each do |left, right|
      assert_equal right, left
    end
  end
end
