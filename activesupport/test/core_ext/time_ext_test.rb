require 'test/unit'
require File.dirname(__FILE__) + '/../../lib/active_support/core_ext/numeric'
require File.dirname(__FILE__) + '/../../lib/active_support/core_ext/time'

class TimeExtCalculationsTest < Test::Unit::TestCase
  def test_seconds_since_midnight
    assert_equal 1,Time.local(2005,1,1,0,0,1).seconds_since_midnight
    assert_equal 60,Time.local(2005,1,1,0,1,0).seconds_since_midnight
    assert_equal 3660,Time.local(2005,1,1,1,1,0).seconds_since_midnight
    assert_equal 86399,Time.local(2005,1,1,23,59,59).seconds_since_midnight
    assert_equal 60.00001,Time.local(2005,1,1,0,1,0,10).seconds_since_midnight
  end

  def test_begining_of_week
    assert_equal Time.local(2005,1,30), Time.local(2005,2,4,10,10,10).beginning_of_week
  end
  
  def test_beginning_of_day
    assert_equal Time.local(2005,2,4,0,0,0), Time.local(2005,2,4,10,10,10).beginning_of_day
  end
  
  def test_beginning_of_month
    assert_equal Time.local(2005,2,1,0,0,0), Time.local(2005,2,22,10,10,10).beginning_of_month
  end
    
  def test_months_ago
    assert_equal Time.local(2005,5,5,10),  Time.local(2005,6,5,10,0,0).months_ago(1)
    assert_equal Time.local(2004,11,5,10), Time.local(2005,6,5,10,0,0).months_ago(7)
    assert_equal Time.local(2004,12,5,10), Time.local(2005,6,5,10,0,0).months_ago(6)
    assert_equal Time.local(2004,6,5,10),  Time.local(2005,6,5,10,0,0).months_ago(12)
    assert_equal Time.local(2003,6,5,10),  Time.local(2005,6,5,10,0,0).months_ago(24)
  end

  def test_months_since
    assert_equal Time.local(2005,7,5,10),  Time.local(2005,6,5,10,0,0).months_since(1)
    assert_equal Time.local(2005,12,5,10), Time.local(2005,6,5,10,0,0).months_since(6)
    assert_equal Time.local(2006,1,5,10),  Time.local(2005,6,5,10,0,0).months_since(7)
    assert_equal Time.local(2006,6,5,10),  Time.local(2005,6,5,10,0,0).months_since(12)
    assert_equal Time.local(2007,6,5,10),  Time.local(2005,6,5,10,0,0).months_since(24)
  end

  def test_ago
    assert_equal Time.local(2005,2,22,10,10,9),  Time.local(2005,2,22,10,10,10).ago(1)
    assert_equal Time.local(2005,2,22,9,10,10),  Time.local(2005,2,22,10,10,10).ago(3600)
    assert_equal Time.local(2005,2,20,10,10,10), Time.local(2005,2,22,10,10,10).ago(86400*2)
    assert_equal Time.local(2005,2,20,9,9,45),   Time.local(2005,2,22,10,10,10).ago(86400*2 + 3600 + 25)
  end 
  
  def test_since
    assert_equal Time.local(2005,2,22,10,10,11), Time.local(2005,2,22,10,10,10).since(1)
    assert_equal Time.local(2005,2,22,11,10,10), Time.local(2005,2,22,10,10,10).since(3600)
    assert_equal Time.local(2005,2,24,10,10,10), Time.local(2005,2,22,10,10,10).since(86400*2)
    assert_equal Time.local(2005,2,24,11,10,35), Time.local(2005,2,22,10,10,10).since(86400*2 + 3600 + 25)
  end

  def test_yesterday
    assert_equal Time.local(2005,2,21,10,10,10), Time.local(2005,2,22,10,10,10).yesterday
    assert_equal Time.local(2005,2,28,10,10,10), Time.local(2005,3,2,10,10,10).yesterday.yesterday
  end
  
  def test_tomorrow
    assert_equal Time.local(2005,2,23,10,10,10), Time.local(2005,2,22,10,10,10).tomorrow
    assert_equal Time.local(2005,3,2,10,10,10),  Time.local(2005,2,28,10,10,10).tomorrow.tomorrow
  end

  def test_in_the_morning
    assert_equal Time.local(2005,2,22,9), Time.local(2005,2,22,15,15,10).in_the_morning
    assert_equal Time.local(2005,2,22,9), Time.local(2005,2,22,3,15,10).in_the_morning
  end

  def test_in_the_morning
    assert_equal Time.local(2005,2,22,14), Time.local(2005,2,22,15,15,10).in_the_afternoon
    assert_equal Time.local(2005,2,22,14), Time.local(2005,2,22,3,15,10).in_the_afternoon
  end
  
  def test_change
    assert_equal Time.local(2006,2,22,15,15,10), Time.local(2005,2,22,15,15,10).change(:year => 2006)
    assert_equal Time.local(2005,6,22,15,15,10), Time.local(2005,2,22,15,15,10).change(:month => 6)
    assert_equal Time.local(2012,9,22,15,15,10), Time.local(2005,2,22,15,15,10).change(:year => 2012, :month => 9)
    assert_equal Time.local(2005,2,22,16), Time.local(2005,2,22,15,15,10).change(:hour => 16)
    assert_equal Time.local(2005,2,22,16,45), Time.local(2005,2,22,15,15,10).change(:hour => 16, :min => 45)
    assert_equal Time.local(2005,2,22,15,45), Time.local(2005,2,22,15,15,10).change(:min => 45)
  end
end