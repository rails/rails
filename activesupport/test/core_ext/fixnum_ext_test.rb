require 'test/unit'
require File.dirname(__FILE__) + '/../../lib/core_ext/fixnum_ext'

class FixnumExtTest < Test::Unit::TestCase
  def test_time_units
    expected = {
      1.minute   => 60,
      10.minutes => 600,
      1.hour + 15.minutes => 4500,
      2.days + 4.hours + 30.minutes => 189000,
      5.years + 1.month + 1.fortnight => 161481600
    }

    expected.each { |actual, expected| assert_equal expected, actual }
  end
end