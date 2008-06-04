require 'abstract_unit'

class DateTimeExtCalculationsTest < Test::Unit::TestCase
  def test_to_s
    datetime = DateTime.new(2005, 2, 21, 14, 30, 0, 0)
    assert_equal "2005-02-21 14:30:00",               datetime.to_s(:db)
    assert_equal "14:30",                             datetime.to_s(:time)
    assert_equal "21 Feb 14:30",                      datetime.to_s(:short)
    assert_equal "February 21, 2005 14:30",           datetime.to_s(:long)
    assert_equal "Mon, 21 Feb 2005 14:30:00 +0000",   datetime.to_s(:rfc822)
    assert_equal "February 21st, 2005 14:30",         datetime.to_s(:long_ordinal)
    assert_match(/^2005-02-21T14:30:00(Z|\+00:00)$/,  datetime.to_s)
  end

  def test_readable_inspect
    datetime = DateTime.new(2005, 2, 21, 14, 30, 0)
    assert_equal "Mon, 21 Feb 2005 14:30:00 +0000", datetime.readable_inspect
    assert_equal datetime.readable_inspect, datetime.inspect
  end

  def test_custom_date_format
    Time::DATE_FORMATS[:custom] = '%Y%m%d%H%M%S'
    assert_equal '20050221143000', DateTime.new(2005, 2, 21, 14, 30, 0).to_s(:custom)
    Time::DATE_FORMATS.delete(:custom)
  end

  def test_to_date
    assert_equal Date.new(2005, 2, 21), DateTime.new(2005, 2, 21).to_date
  end

  def test_to_datetime
    assert_equal DateTime.new(2005, 2, 21), DateTime.new(2005, 2, 21).to_datetime
  end

  def test_to_time
    assert_equal Time.utc(2005, 2, 21, 10, 11, 12), DateTime.new(2005, 2, 21, 10, 11, 12, 0, 0).to_time
    assert_equal Time.utc_time(2039, 2, 21, 10, 11, 12), DateTime.new(2039, 2, 21, 10, 11, 12, 0, 0).to_time
    # DateTimes with offsets other than 0 are returned unaltered
    assert_equal DateTime.new(2005, 2, 21, 10, 11, 12, Rational(-5, 24)), DateTime.new(2005, 2, 21, 10, 11, 12, Rational(-5, 24)).to_time
  end

  def test_seconds_since_midnight
    assert_equal 1,DateTime.civil(2005,1,1,0,0,1).seconds_since_midnight
    assert_equal 60,DateTime.civil(2005,1,1,0,1,0).seconds_since_midnight
    assert_equal 3660,DateTime.civil(2005,1,1,1,1,0).seconds_since_midnight
    assert_equal 86399,DateTime.civil(2005,1,1,23,59,59).seconds_since_midnight
  end

  def test_beginning_of_week
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

  def test_end_of_day
    assert_equal DateTime.civil(2005,2,4,23,59,59), DateTime.civil(2005,2,4,10,10,10).end_of_day
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
    assert_equal DateTime.civil(2005,3,31,23,59,59), DateTime.civil(2005,3,20,10,10,10).end_of_month
    assert_equal DateTime.civil(2005,2,28,23,59,59), DateTime.civil(2005,2,20,10,10,10).end_of_month
    assert_equal DateTime.civil(2005,4,30,23,59,59), DateTime.civil(2005,4,20,10,10,10).end_of_month
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
    assert_equal DateTime.civil(2005,4,30,10),  DateTime.civil(2005,3,31,10,0,0).months_since(1)
    assert_equal DateTime.civil(2005,2,28,10),  DateTime.civil(2005,1,29,10,0,0).months_since(1)
    assert_equal DateTime.civil(2005,2,28,10),  DateTime.civil(2005,1,30,10,0,0).months_since(1)
    assert_equal DateTime.civil(2005,2,28,10),  DateTime.civil(2005,1,31,10,0,0).months_since(1)
  end

  def test_years_ago
    assert_equal DateTime.civil(2004,6,5,10),  DateTime.civil(2005,6,5,10,0,0).years_ago(1)
    assert_equal DateTime.civil(1998,6,5,10), DateTime.civil(2005,6,5,10,0,0).years_ago(7)
    assert_equal DateTime.civil(2003,2,28,10), DateTime.civil(2004,2,29,10,0,0).years_ago(1) # 1 year ago from leap day
  end

  def test_years_since
    assert_equal DateTime.civil(2006,6,5,10),  DateTime.civil(2005,6,5,10,0,0).years_since(1)
    assert_equal DateTime.civil(2012,6,5,10),  DateTime.civil(2005,6,5,10,0,0).years_since(7)
    assert_equal DateTime.civil(2182,6,5,10),  DateTime.civil(2005,6,5,10,0,0).years_since(177)
    assert_equal DateTime.civil(2005,2,28,10), DateTime.civil(2004,2,29,10,0,0).years_since(1) # 1 year since leap day
  end

  def test_last_year
    assert_equal DateTime.civil(2004,6,5,10),  DateTime.civil(2005,6,5,10,0,0).last_year
  end

  def test_next_year
    assert_equal DateTime.civil(2006,6,5,10), DateTime.civil(2005,6,5,10,0,0).next_year
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

  def test_advance
    assert_equal DateTime.civil(2006,2,28,15,15,10), DateTime.civil(2005,2,28,15,15,10).advance(:years => 1)
    assert_equal DateTime.civil(2005,6,28,15,15,10), DateTime.civil(2005,2,28,15,15,10).advance(:months => 4)
    assert_equal DateTime.civil(2005,3,21,15,15,10), DateTime.civil(2005,2,28,15,15,10).advance(:weeks => 3)
    assert_equal DateTime.civil(2005,3,5,15,15,10), DateTime.civil(2005,2,28,15,15,10).advance(:days => 5)
    assert_equal DateTime.civil(2012,9,28,15,15,10), DateTime.civil(2005,2,28,15,15,10).advance(:years => 7, :months => 7)
    assert_equal DateTime.civil(2013,10,3,15,15,10), DateTime.civil(2005,2,28,15,15,10).advance(:years => 7, :months => 19, :days => 5)
    assert_equal DateTime.civil(2013,10,17,15,15,10), DateTime.civil(2005,2,28,15,15,10).advance(:years => 7, :months => 19, :weeks => 2, :days => 5)
    assert_equal DateTime.civil(2001,12,27,15,15,10), DateTime.civil(2005,2,28,15,15,10).advance(:years => -3, :months => -2, :days => -1)
    assert_equal DateTime.civil(2005,2,28,15,15,10), DateTime.civil(2004,2,29,15,15,10).advance(:years => 1) #leap day plus one year
    assert_equal DateTime.civil(2005,2,28,20,15,10), DateTime.civil(2005,2,28,15,15,10).advance(:hours => 5)
    assert_equal DateTime.civil(2005,2,28,15,22,10), DateTime.civil(2005,2,28,15,15,10).advance(:minutes => 7)
    assert_equal DateTime.civil(2005,2,28,15,15,19), DateTime.civil(2005,2,28,15,15,10).advance(:seconds => 9)
    assert_equal DateTime.civil(2005,2,28,20,22,19), DateTime.civil(2005,2,28,15,15,10).advance(:hours => 5, :minutes => 7, :seconds => 9)
    assert_equal DateTime.civil(2005,2,28,10,8,1), DateTime.civil(2005,2,28,15,15,10).advance(:hours => -5, :minutes => -7, :seconds => -9)
    assert_equal DateTime.civil(2013,10,17,20,22,19), DateTime.civil(2005,2,28,15,15,10).advance(:years => 7, :months => 19, :weeks => 2, :days => 5, :hours => 5, :minutes => 7, :seconds => 9)

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

  def test_xmlschema
    assert_match(/^1880-02-28T15:15:10\+00:?00$/, DateTime.civil(1880, 2, 28, 15, 15, 10).xmlschema)
    assert_match(/^1980-02-28T15:15:10\+00:?00$/, DateTime.civil(1980, 2, 28, 15, 15, 10).xmlschema)
    assert_match(/^2080-02-28T15:15:10\+00:?00$/, DateTime.civil(2080, 2, 28, 15, 15, 10).xmlschema)
    assert_match(/^1880-02-28T15:15:10-06:?00$/, DateTime.civil(1880, 2, 28, 15, 15, 10, -0.25).xmlschema)
    assert_match(/^1980-02-28T15:15:10-06:?00$/, DateTime.civil(1980, 2, 28, 15, 15, 10, -0.25).xmlschema)
    assert_match(/^2080-02-28T15:15:10-06:?00$/, DateTime.civil(2080, 2, 28, 15, 15, 10, -0.25).xmlschema)
  end

  def test_acts_like_time
    assert DateTime.new.acts_like_time?
  end

  def test_local_offset
    with_env_tz 'US/Eastern' do
      assert_equal Rational(-5, 24), DateTime.local_offset
    end
    with_env_tz 'US/Central' do
      assert_equal Rational(-6, 24), DateTime.local_offset
    end
  end

  def test_utc?
    assert_equal true, DateTime.civil(2005, 2, 21, 10, 11, 12).utc?
    assert_equal true, DateTime.civil(2005, 2, 21, 10, 11, 12, 0).utc?
    assert_equal false, DateTime.civil(2005, 2, 21, 10, 11, 12, 0.25).utc?
    assert_equal false, DateTime.civil(2005, 2, 21, 10, 11, 12, -0.25).utc?
  end

  def test_utc_offset
    assert_equal 0, DateTime.civil(2005, 2, 21, 10, 11, 12).utc_offset
    assert_equal 0, DateTime.civil(2005, 2, 21, 10, 11, 12, 0).utc_offset
    assert_equal 21600, DateTime.civil(2005, 2, 21, 10, 11, 12, 0.25).utc_offset
    assert_equal( -21600, DateTime.civil(2005, 2, 21, 10, 11, 12, -0.25).utc_offset )
    assert_equal( -18000, DateTime.civil(2005, 2, 21, 10, 11, 12, Rational(-5, 24)).utc_offset )
  end

  def test_utc
    assert_equal DateTime.civil(2005, 2, 21, 16, 11, 12, 0), DateTime.civil(2005, 2, 21, 10, 11, 12, Rational(-6, 24)).utc
    assert_equal DateTime.civil(2005, 2, 21, 15, 11, 12, 0), DateTime.civil(2005, 2, 21, 10, 11, 12, Rational(-5, 24)).utc
    assert_equal DateTime.civil(2005, 2, 21, 10, 11, 12, 0), DateTime.civil(2005, 2, 21, 10, 11, 12, 0).utc
    assert_equal DateTime.civil(2005, 2, 21, 9, 11, 12, 0), DateTime.civil(2005, 2, 21, 10, 11, 12, Rational(1, 24)).utc
    assert_equal DateTime.civil(2005, 2, 21, 9, 11, 12, 0), DateTime.civil(2005, 2, 21, 10, 11, 12, Rational(1, 24)).getutc
  end

  def test_formatted_offset_with_utc
    assert_equal '+00:00', DateTime.civil(2000).formatted_offset
    assert_equal '+0000', DateTime.civil(2000).formatted_offset(false)
    assert_equal 'UTC', DateTime.civil(2000).formatted_offset(true, 'UTC')
  end

  def test_formatted_offset_with_local
    dt = DateTime.civil(2005, 2, 21, 10, 11, 12, Rational(-5, 24))
    assert_equal '-05:00', dt.formatted_offset
    assert_equal '-0500', dt.formatted_offset(false)
  end

  def test_compare_with_time
    assert_equal  1, DateTime.civil(2000) <=> Time.utc(1999, 12, 31, 23, 59, 59)
    assert_equal  0, DateTime.civil(2000) <=> Time.utc(2000, 1, 1, 0, 0, 0)
    assert_equal(-1, DateTime.civil(2000) <=> Time.utc(2000, 1, 1, 0, 0, 1))
  end

  def test_compare_with_datetime
    assert_equal  1, DateTime.civil(2000) <=> DateTime.civil(1999, 12, 31, 23, 59, 59)
    assert_equal  0, DateTime.civil(2000) <=> DateTime.civil(2000, 1, 1, 0, 0, 0)
    assert_equal(-1, DateTime.civil(2000) <=> DateTime.civil(2000, 1, 1, 0, 0, 1))
  end

  def test_compare_with_time_with_zone
    assert_equal  1, DateTime.civil(2000) <=> ActiveSupport::TimeWithZone.new( Time.utc(1999, 12, 31, 23, 59, 59), ActiveSupport::TimeZone['UTC'] )
    assert_equal  0, DateTime.civil(2000) <=> ActiveSupport::TimeWithZone.new( Time.utc(2000, 1, 1, 0, 0, 0), ActiveSupport::TimeZone['UTC'] )
    assert_equal(-1, DateTime.civil(2000) <=> ActiveSupport::TimeWithZone.new( Time.utc(2000, 1, 1, 0, 0, 1), ActiveSupport::TimeZone['UTC'] ))
  end

  def test_to_f
    assert_equal 946684800.0, DateTime.civil(2000).to_f
    assert_equal 946684800.0, DateTime.civil(1999,12,31,19,0,0,Rational(-5,24)).to_f
  end

  protected
    def with_env_tz(new_tz = 'US/Eastern')
      old_tz, ENV['TZ'] = ENV['TZ'], new_tz
      yield
    ensure
      old_tz ? ENV['TZ'] = old_tz : ENV.delete('TZ')
    end
end
