require File.dirname(__FILE__) + '/../abstract_unit'

class TimeExtCalculationsTest < Test::Unit::TestCase
  def test_seconds_since_midnight
    assert_equal 1,Time.local(2005,1,1,0,0,1).seconds_since_midnight
    assert_equal 60,Time.local(2005,1,1,0,1,0).seconds_since_midnight
    assert_equal 3660,Time.local(2005,1,1,1,1,0).seconds_since_midnight
    assert_equal 86399,Time.local(2005,1,1,23,59,59).seconds_since_midnight
    assert_equal 60.00001,Time.local(2005,1,1,0,1,0,10).seconds_since_midnight
  end

  def test_seconds_since_midnight_at_daylight_savings_time_start
    with_timezone 'US/Eastern' do
      # dt: US: 2005 April 3rd 2:00am ST => April 3rd 3:00am DT
      assert_equal 2*3600-1, Time.local(2005,4,3,1,59,59).seconds_since_midnight, 'just before DST start'
      assert_equal 2*3600+1, Time.local(2005,4,3,3, 0, 1).seconds_since_midnight, 'just after DST start'
    end

    with_timezone 'NZ' do
      # dt: New Zealand: 2006 October 1st 2:00am ST => October 1st 3:00am DT
      assert_equal 2*3600-1, Time.local(2006,10,1,1,59,59).seconds_since_midnight, 'just before DST start'
      assert_equal 2*3600+1, Time.local(2006,10,1,3, 0, 1).seconds_since_midnight, 'just after DST start'
    end
  end

  def test_seconds_since_midnight_at_daylight_savings_time_end
    with_timezone 'US/Eastern' do
      # st: US: 2005 October 30th 2:00am DT => October 30th 1:00am ST
      # avoid setting a time between 1:00 and 2:00 since that requires specifying whether DST is active
      assert_equal 1*3600-1, Time.local(2005,10,30,0,59,59).seconds_since_midnight, 'just before DST end'
      assert_equal 3*3600+1, Time.local(2005,10,30,2, 0, 1).seconds_since_midnight, 'just after DST end'

      # now set a time between 1:00 and 2:00 by specifying whether DST is active
      # uses: Time.local( sec, min, hour, day, month, year, wday, yday, isdst, tz )
      assert_equal 1*3600+30*60, Time.local(0,30,1,30,10,2005,0,0,true,ENV['TZ']).seconds_since_midnight, 'before DST end'
      assert_equal 2*3600+30*60, Time.local(0,30,1,30,10,2005,0,0,false,ENV['TZ']).seconds_since_midnight, 'after DST end'
    end

    with_timezone 'NZ' do
      # st: New Zealand: 2006 March 19th 3:00am DT => March 19th 2:00am ST
      # avoid setting a time between 2:00 and 3:00 since that requires specifying whether DST is active
      assert_equal 2*3600-1, Time.local(2006,3,19,1,59,59).seconds_since_midnight, 'just before DST end'
      assert_equal 4*3600+1, Time.local(2006,3,19,3, 0, 1).seconds_since_midnight, 'just after DST end'

      # now set a time between 2:00 and 3:00 by specifying whether DST is active
      # uses: Time.local( sec, min, hour, day, month, year, wday, yday, isdst, tz )
      assert_equal 2*3600+30*60, Time.local(0,30,2,19,3,2006,0,0,true, ENV['TZ']).seconds_since_midnight, 'before DST end'
      assert_equal 3*3600+30*60, Time.local(0,30,2,19,3,2006,0,0,false,ENV['TZ']).seconds_since_midnight, 'after DST end'
    end
  end

  def test_begining_of_week
    assert_equal Time.local(2005,1,31), Time.local(2005,2,4,10,10,10).beginning_of_week
    assert_equal Time.local(2005,11,28), Time.local(2005,11,28,0,0,0).beginning_of_week #monday
    assert_equal Time.local(2005,11,28), Time.local(2005,11,29,0,0,0).beginning_of_week #tuesday
    assert_equal Time.local(2005,11,28), Time.local(2005,11,30,0,0,0).beginning_of_week #wednesday
    assert_equal Time.local(2005,11,28), Time.local(2005,12,01,0,0,0).beginning_of_week #thursday
    assert_equal Time.local(2005,11,28), Time.local(2005,12,02,0,0,0).beginning_of_week #friday
    assert_equal Time.local(2005,11,28), Time.local(2005,12,03,0,0,0).beginning_of_week #saturday
    assert_equal Time.local(2005,11,28), Time.local(2005,12,04,0,0,0).beginning_of_week #sunday
  end

  def test_beginning_of_day
    assert_equal Time.local(2005,2,4,0,0,0), Time.local(2005,2,4,10,10,10).beginning_of_day
    with_timezone 'US/Eastern' do
      assert_equal Time.local(2006,4,2,0,0,0), Time.local(2006,4,2,10,10,10).beginning_of_day, 'start DST'
      assert_equal Time.local(2006,10,29,0,0,0), Time.local(2006,10,29,10,10,10).beginning_of_day, 'ends DST'
    end
    with_timezone 'NZ' do
      assert_equal Time.local(2006,3,19,0,0,0), Time.local(2006,3,19,10,10,10).beginning_of_day, 'ends DST'
      assert_equal Time.local(2006,10,1,0,0,0), Time.local(2006,10,1,10,10,10).beginning_of_day, 'start DST'
    end
  end

  def test_beginning_of_month
    assert_equal Time.local(2005,2,1,0,0,0), Time.local(2005,2,22,10,10,10).beginning_of_month
  end

  def test_beginning_of_quarter
    assert_equal Time.local(2005,1,1,0,0,0), Time.local(2005,2,15,10,10,10).beginning_of_quarter
    assert_equal Time.local(2005,1,1,0,0,0), Time.local(2005,1,1,0,0,0).beginning_of_quarter
    assert_equal Time.local(2005,10,1,0,0,0), Time.local(2005,12,31,10,10,10).beginning_of_quarter
    assert_equal Time.local(2005,4,1,0,0,0), Time.local(2005,6,30,23,59,59).beginning_of_quarter
  end

  def test_end_of_month
    assert_equal Time.local(2005,3,31,0,0,0), Time.local(2005,3,20,10,10,10).end_of_month
    assert_equal Time.local(2005,2,28,0,0,0), Time.local(2005,2,20,10,10,10).end_of_month
    assert_equal Time.local(2005,4,30,0,0,0), Time.local(2005,4,20,10,10,10).end_of_month

  end

  def test_beginning_of_year
    assert_equal Time.local(2005,1,1,0,0,0), Time.local(2005,2,22,10,10,10).beginning_of_year
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
    assert_equal Time.local(2006,1,5,10),  Time.local(2005,12,5,10,0,0).months_since(1)
    assert_equal Time.local(2005,12,5,10), Time.local(2005,6,5,10,0,0).months_since(6)
    assert_equal Time.local(2006,6,5,10),  Time.local(2005,12,5,10,0,0).months_since(6)
    assert_equal Time.local(2006,1,5,10),  Time.local(2005,6,5,10,0,0).months_since(7)
    assert_equal Time.local(2006,6,5,10),  Time.local(2005,6,5,10,0,0).months_since(12)
    assert_equal Time.local(2007,6,5,10),  Time.local(2005,6,5,10,0,0).months_since(24)
  end

  def test_years_ago
    assert_equal Time.local(2004,6,5,10),  Time.local(2005,6,5,10,0,0).years_ago(1)
    assert_equal Time.local(1998,6,5,10), Time.local(2005,6,5,10,0,0).years_ago(7)
  end

  def test_years_since
    assert_equal Time.local(2006,6,5,10),  Time.local(2005,6,5,10,0,0).years_since(1)
    assert_equal Time.local(2012,6,5,10),  Time.local(2005,6,5,10,0,0).years_since(7)
    # Failure because of size limitations of numeric?
    # assert_equal Time.local(2182,6,5,10),  Time.local(2005,6,5,10,0,0).years_since(177)
  end

  def test_last_year
    assert_equal Time.local(2004,6,5,10),  Time.local(2005,6,5,10,0,0).last_year
  end

  def test_next_year
    assert_equal Time.local(2006,6,5,10), Time.local(2005,6,5,10,0,0).next_year
  end

  def test_ago
    assert_equal Time.local(2005,2,22,10,10,9),  Time.local(2005,2,22,10,10,10).ago(1)
    assert_equal Time.local(2005,2,22,9,10,10),  Time.local(2005,2,22,10,10,10).ago(3600)
    assert_equal Time.local(2005,2,20,10,10,10), Time.local(2005,2,22,10,10,10).ago(86400*2)
    assert_equal Time.local(2005,2,20,9,9,45),   Time.local(2005,2,22,10,10,10).ago(86400*2 + 3600 + 25)
  end

  def test_daylight_savings_time_crossings_backward_start
    with_timezone 'US/Eastern' do
      # dt: US: 2005 April 3rd 4:18am
      assert_equal Time.local(2005,4,2,4,18,0), Time.local(2005,4,3,4,18,0).ago(86400), 'dt-1.day=>st'
      assert_equal Time.local(2005,4,1,4,18,0), Time.local(2005,4,2,4,18,0).ago(86400), 'st-1.day=>st'
    end
    with_timezone 'NZ' do
      # dt: New Zealand: 2006 October 1st 4:18am
      assert_equal Time.local(2006,9,30,4,18,0), Time.local(2006,10,1,4,18,0).ago(86400), 'dt-1.day=>st'
      assert_equal Time.local(2006,9,29,4,18,0), Time.local(2006,9,30,4,18,0).ago(86400), 'st-1.day=>st'
    end
  end

  def test_daylight_savings_time_crossings_backward_end
    with_timezone 'US/Eastern' do
      # st: US: 2005 October 30th 4:03am
      assert_equal Time.local(2005,10,29,4,3), Time.local(2005,10,30,4,3,0).ago(86400), 'st-1.day=>dt'
      assert_equal Time.local(2005,10,28,4,3), Time.local(2005,10,29,4,3,0).ago(86400), 'dt-1.day=>dt'
    end
    with_timezone 'NZ' do
      # st: New Zealand: 2006 March 19th 4:03am
      assert_equal Time.local(2006,3,18,4,3), Time.local(2006,3,19,4,3,0).ago(86400), 'st-1.day=>dt'
      assert_equal Time.local(2006,3,17,4,3), Time.local(2006,3,18,4,3,0).ago(86400), 'dt-1.day=>dt'
    end
  end

  def test_since
    assert_equal Time.local(2005,2,22,10,10,11), Time.local(2005,2,22,10,10,10).since(1)
    assert_equal Time.local(2005,2,22,11,10,10), Time.local(2005,2,22,10,10,10).since(3600)
    assert_equal Time.local(2005,2,24,10,10,10), Time.local(2005,2,22,10,10,10).since(86400*2)
    assert_equal Time.local(2005,2,24,11,10,35), Time.local(2005,2,22,10,10,10).since(86400*2 + 3600 + 25)
    # when out of range of Time, returns a DateTime
    assert_equal DateTime.civil(2038,1,20,11,59,59), Time.utc(2038,1,18,11,59,59).since(86400*2)
  end

  def test_daylight_savings_time_crossings_forward_start
    with_timezone 'US/Eastern' do
      # st: US: 2005 April 2nd 7:27pm
      assert_equal Time.local(2005,4,3,19,27,0), Time.local(2005,4,2,19,27,0).since(86400), 'st+1.day=>dt'
      assert_equal Time.local(2005,4,4,19,27,0), Time.local(2005,4,3,19,27,0).since(86400), 'dt+1.day=>dt'
    end
    with_timezone 'NZ' do
      # st: New Zealand: 2006 September 30th 7:27pm
      assert_equal Time.local(2006,10,1,19,27,0), Time.local(2006,9,30,19,27,0).since(86400), 'st+1.day=>dt'
      assert_equal Time.local(2006,10,2,19,27,0), Time.local(2006,10,1,19,27,0).since(86400), 'dt+1.day=>dt'
    end
  end

  def test_daylight_savings_time_crossings_forward_end
    with_timezone 'US/Eastern' do
      # dt: US: 2005 October 30th 12:45am
      assert_equal Time.local(2005,10,31,0,45,0), Time.local(2005,10,30,0,45,0).since(86400), 'dt+1.day=>st'
      assert_equal Time.local(2005,11, 1,0,45,0), Time.local(2005,10,31,0,45,0).since(86400), 'st+1.day=>st'
    end
    with_timezone 'NZ' do
      # dt: New Zealand: 2006 March 19th 1:45am
      assert_equal Time.local(2006,3,20,1,45,0), Time.local(2006,3,19,1,45,0).since(86400), 'dt+1.day=>st'
      assert_equal Time.local(2006,3,21,1,45,0), Time.local(2006,3,20,1,45,0).since(86400), 'st+1.day=>st'
    end
  end

  def test_yesterday
    assert_equal Time.local(2005,2,21,10,10,10), Time.local(2005,2,22,10,10,10).yesterday
    assert_equal Time.local(2005,2,28,10,10,10), Time.local(2005,3,2,10,10,10).yesterday.yesterday
  end

  def test_tomorrow
    assert_equal Time.local(2005,2,23,10,10,10), Time.local(2005,2,22,10,10,10).tomorrow
    assert_equal Time.local(2005,3,2,10,10,10),  Time.local(2005,2,28,10,10,10).tomorrow.tomorrow
  end

  def test_change
    assert_equal Time.local(2006,2,22,15,15,10), Time.local(2005,2,22,15,15,10).change(:year => 2006)
    assert_equal Time.local(2005,6,22,15,15,10), Time.local(2005,2,22,15,15,10).change(:month => 6)
    assert_equal Time.local(2012,9,22,15,15,10), Time.local(2005,2,22,15,15,10).change(:year => 2012, :month => 9)
    assert_equal Time.local(2005,2,22,16),       Time.local(2005,2,22,15,15,10).change(:hour => 16)
    assert_equal Time.local(2005,2,22,16,45),    Time.local(2005,2,22,15,15,10).change(:hour => 16, :min => 45)
    assert_equal Time.local(2005,2,22,15,45),    Time.local(2005,2,22,15,15,10).change(:min => 45)

    assert_equal Time.local(2005,1,2, 5, 0, 0, 0), Time.local(2005,1,2,11,22,33,44).change(:hour => 5)
    assert_equal Time.local(2005,1,2,11, 6, 0, 0), Time.local(2005,1,2,11,22,33,44).change(:min  => 6)
    assert_equal Time.local(2005,1,2,11,22, 7, 0), Time.local(2005,1,2,11,22,33,44).change(:sec  => 7)
    assert_equal Time.local(2005,1,2,11,22,33, 8), Time.local(2005,1,2,11,22,33,44).change(:usec => 8)
  end

  def test_utc_change
    assert_equal Time.utc(2006,2,22,15,15,10), Time.utc(2005,2,22,15,15,10).change(:year => 2006)
    assert_equal Time.utc(2005,6,22,15,15,10), Time.utc(2005,2,22,15,15,10).change(:month => 6)
    assert_equal Time.utc(2012,9,22,15,15,10), Time.utc(2005,2,22,15,15,10).change(:year => 2012, :month => 9)
    assert_equal Time.utc(2005,2,22,16),       Time.utc(2005,2,22,15,15,10).change(:hour => 16)
    assert_equal Time.utc(2005,2,22,16,45),    Time.utc(2005,2,22,15,15,10).change(:hour => 16, :min => 45)
    assert_equal Time.utc(2005,2,22,15,45),    Time.utc(2005,2,22,15,15,10).change(:min => 45)
  end

  def test_plus
    assert_equal Time.local(2006,2,28,15,15,10), Time.local(2005,2,28,15,15,10).advance(:years => 1)
    assert_equal Time.local(2005,6,28,15,15,10), Time.local(2005,2,28,15,15,10).advance(:months => 4)
    assert_equal Time.local(2012,9,28,15,15,10), Time.local(2005,2,28,15,15,10).advance(:years => 7, :months => 7)
    assert_equal Time.local(2013,10,3,15,15,10), Time.local(2005,2,28,15,15,10).advance(:years => 7, :months => 19, :days => 5)
  end

  def test_utc_plus
    assert_equal Time.utc(2006,2,22,15,15,10), Time.utc(2005,2,22,15,15,10).advance(:years => 1)
    assert_equal Time.utc(2005,6,22,15,15,10), Time.utc(2005,2,22,15,15,10).advance(:months => 4)
    assert_equal Time.utc(2012,9,22,15,15,10), Time.utc(2005,2,22,15,15,10).advance(:years => 7, :months => 7)
    assert_equal Time.utc(2013,10,3,15,15,10), Time.utc(2005,2,22,15,15,10).advance(:years => 7, :months => 19, :days => 11)
  end

  def test_next_week
    assert_equal Time.local(2005,2,28), Time.local(2005,2,22,15,15,10).next_week
    assert_equal Time.local(2005,2,29), Time.local(2005,2,22,15,15,10).next_week(:tuesday)
    assert_equal Time.local(2005,3,4), Time.local(2005,2,22,15,15,10).next_week(:friday)
    assert_equal Time.local(2006,10,30), Time.local(2006,10,23,0,0,0).next_week
    assert_equal Time.local(2006,11,1), Time.local(2006,10,23,0,0,0).next_week(:wednesday)
  end

  def test_next_week_near_daylight_start
    with_timezone 'US/Eastern' do
      assert_equal Time.local(2006,4,3), Time.local(2006,4,2,23,1,0).next_week, 'just crossed standard => daylight'
    end
    with_timezone 'NZ' do
      assert_equal Time.local(2006,10,2), Time.local(2006,10,1,23,1,0).next_week, 'just crossed standard => daylight'
    end
  end

  def test_next_week_near_daylight_end
    with_timezone 'US/Eastern' do
      assert_equal Time.local(2006,10,30), Time.local(2006,10,29,23,1,0).next_week, 'just crossed daylight => standard'
    end
    with_timezone 'NZ' do
      assert_equal Time.local(2006,3,20), Time.local(2006,3,19,23,1,0).next_week, 'just crossed daylight => standard'
    end
  end

  def test_to_s
    time = Time.utc(2005, 2, 21, 17, 44, 30)
    assert_equal "Mon Feb 21 17:44:30 UTC 2005",    time.to_s
    assert_equal "2005-02-21 17:44:30",             time.to_s(:db)
    assert_equal "21 Feb 17:44",                    time.to_s(:short)
    assert_equal "17:44",                           time.to_s(:time)
    assert_equal "February 21, 2005 17:44",         time.to_s(:long)
    assert_equal "February 21st, 2005 17:44",       time.to_s(:long_ordinal)
    assert_equal "Mon, 21 Feb 2005 17:44:30 +0000", time.to_s(:rfc822)
  end

  def test_custom_date_format
    Time::DATE_FORMATS[:custom] = '%Y%m%d%H%M%S'
    assert_equal '20050221143000', Time.local(2005, 2, 21, 14, 30, 0).to_s(:custom)
    Time::DATE_FORMATS.delete(:custom)
  end

  def test_to_date
    assert_equal Date.new(2005, 2, 21), Time.local(2005, 2, 21, 17, 44, 30).to_date
  end

  def test_to_datetime
    assert_equal Time.utc(2005, 2, 21, 17, 44, 30).to_datetime, DateTime.civil(2005, 2, 21, 17, 44, 30, 0, 0)
    with_timezone 'US/Eastern' do
      assert_equal Time.local(2005, 2, 21, 17, 44, 30).to_datetime, DateTime.civil(2005, 2, 21, 17, 44, 30, Rational(Time.local(2005, 2, 21, 17, 44, 30).utc_offset, 86400), 0)
    end
    with_timezone 'NZ' do
      assert_equal Time.local(2005, 2, 21, 17, 44, 30).to_datetime, DateTime.civil(2005, 2, 21, 17, 44, 30, Rational(Time.local(2005, 2, 21, 17, 44, 30).utc_offset, 86400), 0)
    end
  end

  def test_to_time
    assert_equal Time.local(2005, 2, 21, 17, 44, 30), Time.local(2005, 2, 21, 17, 44, 30).to_time
  end

  # NOTE: this test seems to fail (changeset 1958) only on certain platforms,
  # like OSX, and FreeBSD 5.4.
  def test_fp_inaccuracy_ticket_1836
    midnight = Time.local(2005, 2, 21, 0, 0, 0)
    assert_equal midnight.midnight, (midnight + 1.hour + 0.000001).midnight
  end

  def test_days_in_month
    assert_equal 31, Time.days_in_month(1, 2005)

    assert_equal 28, Time.days_in_month(2, 2005)
    assert_equal 29, Time.days_in_month(2, 2004)
    assert_equal 29, Time.days_in_month(2, 2000)
    assert_equal 28, Time.days_in_month(2, 1900)

    assert_equal 31, Time.days_in_month(3, 2005)
    assert_equal 30, Time.days_in_month(4, 2005)
    assert_equal 31, Time.days_in_month(5, 2005)
    assert_equal 30, Time.days_in_month(6, 2005)
    assert_equal 31, Time.days_in_month(7, 2005)
    assert_equal 31, Time.days_in_month(8, 2005)
    assert_equal 30, Time.days_in_month(9, 2005)
    assert_equal 31, Time.days_in_month(10, 2005)
    assert_equal 30, Time.days_in_month(11, 2005)
    assert_equal 31, Time.days_in_month(12, 2005)
  end

  def test_time_with_datetime_fallback
    assert_equal Time.time_with_datetime_fallback(:utc, 2005, 2, 21, 17, 44, 30), Time.utc(2005, 2, 21, 17, 44, 30)
    assert_equal Time.time_with_datetime_fallback(:local, 2005, 2, 21, 17, 44, 30), Time.local(2005, 2, 21, 17, 44, 30)
    assert_equal Time.time_with_datetime_fallback(:utc, 2039, 2, 21, 17, 44, 30), DateTime.civil(2039, 2, 21, 17, 44, 30, 0, 0)
    assert_equal Time.time_with_datetime_fallback(:local, 2039, 2, 21, 17, 44, 30), DateTime.civil(2039, 2, 21, 17, 44, 30, DateTime.now.offset, 0)
    assert_equal Time.time_with_datetime_fallback(:utc, 1900, 2, 21, 17, 44, 30), DateTime.civil(1900, 2, 21, 17, 44, 30, 0, 0)
    assert_equal Time.time_with_datetime_fallback(:local, 1900, 2, 21, 17, 44, 30), DateTime.civil(1900, 2, 21, 17, 44, 30, DateTime.now.offset, 0)
    assert_equal Time.time_with_datetime_fallback(:utc, 2005), Time.utc(2005)
    assert_equal Time.time_with_datetime_fallback(:utc, 2039), DateTime.civil(2039, 1, 1, 0, 0, 0, 0, 0)
    assert_equal Time.time_with_datetime_fallback(:utc, 2005, 2, 21, 17, 44, 30, 1), Time.utc(2005, 2, 21, 17, 44, 30, 1) #with usec
    assert_equal Time.time_with_datetime_fallback(:utc, 2039, 2, 21, 17, 44, 30, 1), DateTime.civil(2039, 2, 21, 17, 44, 30, 0, 0)
  end

  def test_utc_time
    assert_equal Time.utc_time(2005, 2, 21, 17, 44, 30), Time.utc(2005, 2, 21, 17, 44, 30)
    assert_equal Time.utc_time(2039, 2, 21, 17, 44, 30), DateTime.civil(2039, 2, 21, 17, 44, 30, 0, 0)
    assert_equal Time.utc_time(1901, 2, 21, 17, 44, 30), DateTime.civil(1901, 2, 21, 17, 44, 30, 0, 0)
  end

  def test_local_time
    assert_equal Time.local_time(2005, 2, 21, 17, 44, 30), Time.local(2005, 2, 21, 17, 44, 30)
    assert_equal Time.local_time(2039, 2, 21, 17, 44, 30), DateTime.civil(2039, 2, 21, 17, 44, 30, DateTime.now.offset, 0)
    assert_equal Time.local_time(1901, 2, 21, 17, 44, 30), DateTime.civil(1901, 2, 21, 17, 44, 30, DateTime.now.offset, 0)
  end

  def test_next_month_on_31st
    assert_equal Time.local(2005, 9, 30), Time.local(2005, 8, 31).next_month
  end

  def test_last_month_on_31st
    assert_equal Time.local(2004, 2, 29), Time.local(2004, 3, 31).last_month
  end

  def test_xmlschema_is_available
    assert_nothing_raised { Time.now.xmlschema }
  end

  def test_acts_like_time
    assert Time.new.acts_like_time?
  end

  protected
    def with_timezone new_tz='US/Eastern'
      old_tz, ENV['TZ'] = ENV['TZ'], new_tz
      yield
    ensure
      ENV['TZ'] = old_tz
    end
end
