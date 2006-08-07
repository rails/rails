require File.dirname(__FILE__) + '/../abstract_unit'

class DateExtCalculationsTest < Test::Unit::TestCase
  def test_to_s
    assert_equal "21 Feb",            Date.new(2005, 2, 21).to_s(:short)
    assert_equal "February 21, 2005", Date.new(2005, 2, 21).to_s(:long)
  end

  def test_to_time
    assert_equal Time.local(2005, 2, 21), Date.new(2005, 2, 21).to_time
  end

  def test_to_time_on_datetime
    assert_equal Time.local(2005, 2, 21, 10, 11, 12), DateTime.new(2005, 2, 21, 10, 11, 12).to_time
  end

  def test_to_date
    assert_equal Date.new(2005, 2, 21), Date.new(2005, 2, 21).to_date
  end
end
