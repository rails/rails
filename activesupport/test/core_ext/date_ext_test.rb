require File.dirname(__FILE__) + '/../abstract_unit'

class DateExtCalculationsTest < Test::Unit::TestCase
  def test_to_s
    assert_equal "21 Feb",              Date.new(2005, 2, 21).to_s(:short)
    assert_equal "February 21, 2005",   Date.new(2005, 2, 21).to_s(:long)
    assert_equal "February 21st, 2005", Date.new(2005, 2, 21).to_s(:long_ordinal)
    assert_equal "2005-02-21",          Date.new(2005, 2, 21).to_s(:db)
    assert_equal "21 Feb 2005",         Date.new(2005, 2, 21).to_s(:rfc822)
  end

  def test_to_time
    assert_equal Time.local(2005, 2, 21), Date.new(2005, 2, 21).to_time
    assert_equal Time.local_time(2039, 2, 21), Date.new(2039, 2, 21).to_time
  end
  
  def test_to_datetime
    assert_equal DateTime.civil(2005, 2, 21), Date.new(2005, 2, 21).to_datetime
  end

  def test_to_date
    assert_equal Date.new(2005, 2, 21), Date.new(2005, 2, 21).to_date
  end
end
