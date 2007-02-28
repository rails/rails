require File.dirname(__FILE__) + '/../abstract_unit'

class DateTimeExtCalculationsTest < Test::Unit::TestCase
  def test_to_s
    assert_equal "2005-02-21 14:30:00",               DateTime.new(2005, 2, 21, 14, 30, 0).to_s(:db)
    assert_equal "14:30",                             DateTime.new(2005, 2, 21, 14, 30, 0).to_s(:time)
    assert_equal "21 Feb 14:30",                      DateTime.new(2005, 2, 21, 14, 30, 0).to_s(:short)
    assert_equal "February 21, 2005 14:30",           DateTime.new(2005, 2, 21, 14, 30, 0).to_s(:long)
    assert_equal "Mon, 21 Feb 2005 14:30:00 +0000",   DateTime.new(2005, 2, 21, 14, 30, 0).to_s(:rfc822)
  end

  def test_to_date
    assert_equal Date.new(2005, 2, 21), DateTime.new(2005, 2, 21).to_date
  end
end