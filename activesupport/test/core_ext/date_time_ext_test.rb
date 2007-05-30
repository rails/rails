require File.dirname(__FILE__) + '/../abstract_unit'

class DateTimeExtCalculationsTest < Test::Unit::TestCase
  def test_to_s
    datetime = DateTime.new(2005, 2, 21, 14, 30, 0)

    assert_equal "2005-02-21 14:30:00",               datetime.to_s(:db)
    assert_equal "14:30",                             datetime.to_s(:time)
    assert_equal "21 Feb 14:30",                      datetime.to_s(:short)
    assert_equal "February 21, 2005 14:30",           datetime.to_s(:long)
    assert_equal "Mon, 21 Feb 2005 14:30:00 +0000",   datetime.to_s(:rfc822)
    assert_equal "February 21st, 2005 14:30",         datetime.to_s(:long_ordinal)
  end
  
  def test_custom_date_format
    Time::DATE_FORMATS[:custom] = '%Y%m%d%H%M%S'
    assert_equal '20050221143000', DateTime.new(2005, 2, 21, 14, 30, 0).to_s(:custom)
    Time::DATE_FORMATS.delete(:custom)
  end

  def test_to_date
    assert_equal Date.new(2005, 2, 21), DateTime.new(2005, 2, 21).to_date
  end
  
  def test_to_time
    assert_equal Time.utc(2005, 2, 21, 10, 11, 12), DateTime.new(2005, 2, 21, 10, 11, 12, 0, 0).to_time
    assert_equal Time.local(2005, 2, 21, 10, 11, 12), DateTime.new(2005, 2, 21, 10, 11, 12, Rational(-5, 24), 0).to_time
    assert_equal Time.utc_time(2039, 2, 21, 10, 11, 12), DateTime.new(2039, 2, 21, 10, 11, 12, 0, 0).to_time
  end

  def test_seconds_since_midnight
    assert_equal 1,DateTime.civil(2005,1,1,0,0,1).seconds_since_midnight
    assert_equal 60,DateTime.civil(2005,1,1,0,1,0).seconds_since_midnight
    assert_equal 3660,DateTime.civil(2005,1,1,1,1,0).seconds_since_midnight
    assert_equal 86399,DateTime.civil(2005,1,1,23,59,59).seconds_since_midnight
  end

  def test_begining_of_week
    assert_equal DateTime.civil(2005,1,31), DateTime.civil(2005,2,4,10,10,10).beginning_of_week
    assert_equal DateTime.civil(2005,11,28), DateTime.civil(2005,11,28,0,0,0).beginning_of_week #monday
    assert_equal DateTime.civil(2005,11,28), DateTime.civil(2005,11,29,0,0,0).beginning_of_week #tuesday
    assert_equal DateTime.civil(2005,11,28), DateTime.civil(2005,11,30,0,0,0).beginning_of_week #wednesday
    assert_equal DateTime.civil(2005,11,28), DateTime.civil(2005,12,01,0,0,0).beginning_of_week #thursday
    assert_equal DateTime.civil(2005,11,28), DateTime.civil(2005,12,02,0,0,0).beginning_of_week #friday
    assert_equal DateTime.civil(2005,11,28), DateTime.civil(2005,12,03,0,0,0).beginning_of_week #saturday
    assert_equal DateTime.civil(2005,11,28), DateTime.civil(2005,12,04,0,0,0).beginning_of_week #sunday
  end

  def test_beginning_of_day
    assert_equal DateTime.civil(2005,2,4,0,0,0), DateTime.civil(2005,2,4,10,10,10).beginning_of_day
  end

  def test_beginning_of_month
    assert_equal DateTime.civil(2005,2,1,0,0,0), DateTime.civil(2005,2,22,10,10,10).beginning_of_month
  end

  def test_beginning_of_quarter
    assert_equal DateTime.civil(2005,1,1,0,0,0), DateTime.civil(2005,2,15,10,10,10).beginning_of_quarter
    assert_equal DateTime.civil(2005,1,1,0,0,0), DateTime.civil(2005,1,1,0,0,0).beginning_of_quarter
    assert_equal DateTime.civil(2005,10,1,0,0,0), DateTime.civil(2005,12,31,10,10,10).beginning_of_quarter
    assert_equal DateTime.civil(2005,4,1,0,0,0), DateTime.civil(2005,6,30,23,59,59).beginning_of_quarter
  end

  def test_end_of_month
    assert_equal DateTime.civil(2005,3,31,0,0,0), DateTime.civil(2005,3,20,10,10,10).end_of_month
    assert_equal DateTime.civil(2005,2,28,0,0,0), DateTime.civil(2005,2,20,10,10,10).end_of_month
    assert_equal DateTime.civil(2005,4,30,0,0,0), DateTime.civil(2005,4,20,10,10,10).end_of_month

  end

  def test_beginning_of_year
    assert_equal DateTime.civil(2005,1,1,0,0,0), DateTime.civil(2005,2,22,10,10,10).beginning_of_year
  end

  def test_months_ago
    assert_equal DateTime.civil(2005,5,5,10),  DateTime.civil(2005,6,5,10,0,0).months_ago(1)
    assert_equal DateTime.civil(2004,11,5,10), DateTime.civil(2005,6,5,10,0,0).months_ago(7)
    assert_equal DateTime.civil(2004,12,5,10), DateTime.civil(2005,6,5,10,0,0).months_ago(6)
    assert_equal DateTime.civil(2004,6,5,10),  DateTime.civil(2005,6,5,10,0,0).months_ago(12)
    assert_equal DateTime.civil(2003,6,5,10),  DateTime.civil(2005,6,5,10,0,0).months_ago(24)
  end

  def test_months_since
    assert_equal DateTime.civil(2005,7,5,10),  DateTime.civil(2005,6,5,10,0,0).months_since(1)
    assert_equal DateTime.civil(2006,1,5,10),  DateTime.civil(2005,12,5,10,0,0).months_since(1)
    assert_equal DateTime.civil(2005,12,5,10), DateTime.civil(2005,6,5,10,0,0).months_since(6)
    assert_equal DateTime.civil(2006,6,5,10),  DateTime.civil(2005,12,5,10,0,0).months_since(6)
    assert_equal DateTime.civil(2006,1,5,10),  DateTime.civil(2005,6,5,10,0,0).months_since(7)
    assert_equal DateTime.civil(2006,6,5,10),  DateTime.civil(2005,6,5,10,0,0).months_since(12)
    assert_equal DateTime.civil(2007,6,5,10),  DateTime.civil(2005,6,5,10,0,0).months_since(24)
  end

  def test_years_ago
    assert_equal DateTime.civil(2004,6,5,10),  DateTime.civil(2005,6,5,10,0,0).years_ago(1)
    assert_equal DateTime.civil(1998,6,5,10), DateTime.civil(2005,6,5,10,0,0).years_ago(7)
  end

  def test_years_since
    assert_equal DateTime.civil(2006,6,5,10),  DateTime.civil(2005,6,5,10,0,0).years_since(1)
    assert_equal DateTime.civil(2012,6,5,10),  DateTime.civil(2005,6,5,10,0,0).years_since(7)
    assert_equal DateTime.civil(2182,6,5,10),  DateTime.civil(2005,6,5,10,0,0).years_since(177)
  end

  def test_last_year
    assert_equal DateTime.civil(2004,6,5,10),  DateTime.civil(2005,6,5,10,0,0).last_year
  end


  def test_ago
    assert_equal DateTime.civil(2005,2,22,10,10,9),  DateTime.civil(2005,2,22,10,10,10).ago(1)
    assert_equal DateTime.civil(2005,2,22,9,10,10),  DateTime.civil(2005,2,22,10,10,10).ago(3600)
    assert_equal DateTime.civil(2005,2,20,10,10,10), DateTime.civil(2005,2,22,10,10,10).ago(86400*2)
    assert_equal DateTime.civil(2005,2,20,9,9,45),   DateTime.civil(2005,2,22,10,10,10).ago(86400*2 + 3600 + 25)
  end

  def test_since
    assert_equal DateTime.civil(2005,2,22,10,10,11), DateTime.civil(2005,2,22,10,10,10).since(1)
    assert_equal DateTime.civil(2005,2,22,11,10,10), DateTime.civil(2005,2,22,10,10,10).since(3600)
    assert_equal DateTime.civil(2005,2,24,10,10,10), DateTime.civil(2005,2,22,10,10,10).since(86400*2)
    assert_equal DateTime.civil(2005,2,24,11,10,35), DateTime.civil(2005,2,22,10,10,10).since(86400*2 + 3600 + 25)
    assert_equal DateTime.civil(2005,2,22,10,10,11), DateTime.civil(2005,2,22,10,10,10).since(1.333)
    assert_equal DateTime.civil(2005,2,22,10,10,12), DateTime.civil(2005,2,22,10,10,10).since(1.667)
  end

  def test_yesterday
    assert_equal DateTime.civil(2005,2,21,10,10,10), DateTime.civil(2005,2,22,10,10,10).yesterday
    assert_equal DateTime.civil(2005,2,28,10,10,10), DateTime.civil(2005,3,2,10,10,10).yesterday.yesterday
  end

  def test_tomorrow
    assert_equal DateTime.civil(2005,2,23,10,10,10), DateTime.civil(2005,2,22,10,10,10).tomorrow
    assert_equal DateTime.civil(2005,3,2,10,10,10),  DateTime.civil(2005,2,28,10,10,10).tomorrow.tomorrow
  end

  def test_change
    assert_equal DateTime.civil(2006,2,22,15,15,10), DateTime.civil(2005,2,22,15,15,10).change(:year => 2006)
    assert_equal DateTime.civil(2005,6,22,15,15,10), DateTime.civil(2005,2,22,15,15,10).change(:month => 6)
    assert_equal DateTime.civil(2012,9,22,15,15,10), DateTime.civil(2005,2,22,15,15,10).change(:year => 2012, :month => 9)
    assert_equal DateTime.civil(2005,2,22,16),       DateTime.civil(2005,2,22,15,15,10).change(:hour => 16)
    assert_equal DateTime.civil(2005,2,22,16,45),    DateTime.civil(2005,2,22,15,15,10).change(:hour => 16, :min => 45)
    assert_equal DateTime.civil(2005,2,22,15,45),    DateTime.civil(2005,2,22,15,15,10).change(:min => 45)
  end

  def test_plus
    assert_equal DateTime.civil(2006,2,28,15,15,10), DateTime.civil(2005,2,28,15,15,10).advance(:years => 1)
    assert_equal DateTime.civil(2005,6,28,15,15,10), DateTime.civil(2005,2,28,15,15,10).advance(:months => 4)
    assert_equal DateTime.civil(2012,9,28,15,15,10), DateTime.civil(2005,2,28,15,15,10).advance(:years => 7, :months => 7)
    assert_equal DateTime.civil(2013,10,3,15,15,10), DateTime.civil(2005,2,28,15,15,10).advance(:years => 7, :months => 19, :days => 5)
  end

  def test_next_week
    assert_equal DateTime.civil(2005,2,28), DateTime.civil(2005,2,22,15,15,10).next_week
    assert_equal DateTime.civil(2005,3,4), DateTime.civil(2005,2,22,15,15,10).next_week(:friday)
    assert_equal DateTime.civil(2006,10,30), DateTime.civil(2006,10,23,0,0,0).next_week
    assert_equal DateTime.civil(2006,11,1), DateTime.civil(2006,10,23,0,0,0).next_week(:wednesday)
  end

  def test_next_month_on_31st
    assert_equal DateTime.civil(2005, 9, 30), DateTime.civil(2005, 8, 31).next_month
  end

  def test_last_month_on_31st
    assert_equal DateTime.civil(2004, 2, 29), DateTime.civil(2004, 3, 31).last_month
  end

  def test_xmlschema_is_available
    assert_nothing_raised { DateTime.now.xmlschema }
  end
end
