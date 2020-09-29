# frozen_string_literal: true

require_relative "../abstract_unit"
require "active_support/time"
require_relative "../core_ext/date_and_time_behavior"
require_relative "../time_zone_test_helpers"

class TimeExtCalculationsTest < ActiveSupport::TestCase
  def date_time_init(year, month, day, hour, minute, second, usec = 0)
    Time.local(year, month, day, hour, minute, second, usec)
  end

  include DateAndTimeBehavior
  include TimeZoneTestHelpers

  def test_seconds_since_midnight
    assert_equal 1, Time.local(2005, 1, 1, 0, 0, 1).seconds_since_midnight
    assert_equal 60, Time.local(2005, 1, 1, 0, 1, 0).seconds_since_midnight
    assert_equal 3660, Time.local(2005, 1, 1, 1, 1, 0).seconds_since_midnight
    assert_equal 86399, Time.local(2005, 1, 1, 23, 59, 59).seconds_since_midnight
    assert_equal 60.00001, Time.local(2005, 1, 1, 0, 1, 0, 10).seconds_since_midnight
  end

  def test_seconds_since_midnight_at_daylight_savings_time_start
    with_env_tz "US/Eastern" do
      # dt: US: 2005 April 3rd 2:00am ST => April 3rd 3:00am DT
      assert_equal 2 * 3600 - 1, Time.local(2005, 4, 3, 1, 59, 59).seconds_since_midnight, "just before DST start"
      assert_equal 2 * 3600 + 1, Time.local(2005, 4, 3, 3, 0, 1).seconds_since_midnight, "just after DST start"
    end

    with_env_tz "NZ" do
      # dt: New Zealand: 2006 October 1st 2:00am ST => October 1st 3:00am DT
      assert_equal 2 * 3600 - 1, Time.local(2006, 10, 1, 1, 59, 59).seconds_since_midnight, "just before DST start"
      assert_equal 2 * 3600 + 1, Time.local(2006, 10, 1, 3, 0, 1).seconds_since_midnight, "just after DST start"
    end
  end

  def test_seconds_since_midnight_at_daylight_savings_time_end
    with_env_tz "US/Eastern" do
      # st: US: 2005 October 30th 2:00am DT => October 30th 1:00am ST
      # avoid setting a time between 1:00 and 2:00 since that requires specifying whether DST is active
      assert_equal 1 * 3600 - 1, Time.local(2005, 10, 30, 0, 59, 59).seconds_since_midnight, "just before DST end"
      assert_equal 3 * 3600 + 1, Time.local(2005, 10, 30, 2, 0, 1).seconds_since_midnight, "just after DST end"

      # now set a time between 1:00 and 2:00 by specifying whether DST is active
      # uses: Time.local( sec, min, hour, day, month, year, wday, yday, isdst, tz )
      assert_equal 1 * 3600 + 30 * 60, Time.local(0, 30, 1, 30, 10, 2005, 0, 0, true, ENV["TZ"]).seconds_since_midnight, "before DST end"
      assert_equal 2 * 3600 + 30 * 60, Time.local(0, 30, 1, 30, 10, 2005, 0, 0, false, ENV["TZ"]).seconds_since_midnight, "after DST end"
    end

    with_env_tz "NZ" do
      # st: New Zealand: 2006 March 19th 3:00am DT => March 19th 2:00am ST
      # avoid setting a time between 2:00 and 3:00 since that requires specifying whether DST is active
      assert_equal 2 * 3600 - 1, Time.local(2006, 3, 19, 1, 59, 59).seconds_since_midnight, "just before DST end"
      assert_equal 4 * 3600 + 1, Time.local(2006, 3, 19, 3, 0, 1).seconds_since_midnight, "just after DST end"

      # now set a time between 2:00 and 3:00 by specifying whether DST is active
      # uses: Time.local( sec, min, hour, day, month, year, wday, yday, isdst, tz )
      assert_equal 2 * 3600 + 30 * 60, Time.local(0, 30, 2, 19, 3, 2006, 0, 0, true, ENV["TZ"]).seconds_since_midnight, "before DST end"
      assert_equal 3 * 3600 + 30 * 60, Time.local(0, 30, 2, 19, 3, 2006, 0, 0, false, ENV["TZ"]).seconds_since_midnight, "after DST end"
    end
  end

  def test_seconds_until_end_of_day
    assert_equal 0, Time.local(2005, 1, 1, 23, 59, 59).seconds_until_end_of_day
    assert_equal 1, Time.local(2005, 1, 1, 23, 59, 58).seconds_until_end_of_day
    assert_equal 60, Time.local(2005, 1, 1, 23, 58, 59).seconds_until_end_of_day
    assert_equal 3660, Time.local(2005, 1, 1, 22, 58, 59).seconds_until_end_of_day
    assert_equal 86399, Time.local(2005, 1, 1, 0, 0, 0).seconds_until_end_of_day
  end

  def test_seconds_until_end_of_day_at_daylight_savings_time_start
    with_env_tz "US/Eastern" do
      # dt: US: 2005 April 3rd 2:00am ST => April 3rd 3:00am DT
      assert_equal 21 * 3600, Time.local(2005, 4, 3, 1, 59, 59).seconds_until_end_of_day, "just before DST start"
      assert_equal 21 * 3600 - 2, Time.local(2005, 4, 3, 3, 0, 1).seconds_until_end_of_day, "just after DST start"
    end

    with_env_tz "NZ" do
      # dt: New Zealand: 2006 October 1st 2:00am ST => October 1st 3:00am DT
      assert_equal 21 * 3600, Time.local(2006, 10, 1, 1, 59, 59).seconds_until_end_of_day, "just before DST start"
      assert_equal 21 * 3600 - 2, Time.local(2006, 10, 1, 3, 0, 1).seconds_until_end_of_day, "just after DST start"
    end
  end

  def test_seconds_until_end_of_day_at_daylight_savings_time_end
    with_env_tz "US/Eastern" do
      # st: US: 2005 October 30th 2:00am DT => October 30th 1:00am ST
      # avoid setting a time between 1:00 and 2:00 since that requires specifying whether DST is active
      assert_equal 24 * 3600, Time.local(2005, 10, 30, 0, 59, 59).seconds_until_end_of_day, "just before DST end"
      assert_equal 22 * 3600 - 2, Time.local(2005, 10, 30, 2, 0, 1).seconds_until_end_of_day, "just after DST end"

      # now set a time between 1:00 and 2:00 by specifying whether DST is active
      # uses: Time.local( sec, min, hour, day, month, year, wday, yday, isdst, tz )
      assert_equal 24 * 3600 - 30 * 60 - 1, Time.local(0, 30, 1, 30, 10, 2005, 0, 0, true, ENV["TZ"]).seconds_until_end_of_day, "before DST end"
      assert_equal 23 * 3600 - 30 * 60 - 1, Time.local(0, 30, 1, 30, 10, 2005, 0, 0, false, ENV["TZ"]).seconds_until_end_of_day, "after DST end"
    end

    with_env_tz "NZ" do
      # st: New Zealand: 2006 March 19th 3:00am DT => March 19th 2:00am ST
      # avoid setting a time between 2:00 and 3:00 since that requires specifying whether DST is active
      assert_equal 23 * 3600, Time.local(2006, 3, 19, 1, 59, 59).seconds_until_end_of_day, "just before DST end"
      assert_equal 21 * 3600 - 2, Time.local(2006, 3, 19, 3, 0, 1).seconds_until_end_of_day, "just after DST end"

      # now set a time between 2:00 and 3:00 by specifying whether DST is active
      # uses: Time.local( sec, min, hour, day, month, year, wday, yday, isdst, tz )
      assert_equal 23 * 3600 - 30 * 60 - 1, Time.local(0, 30, 2, 19, 3, 2006, 0, 0, true, ENV["TZ"]).seconds_until_end_of_day, "before DST end"
      assert_equal 22 * 3600 - 30 * 60 - 1, Time.local(0, 30, 2, 19, 3, 2006, 0, 0, false, ENV["TZ"]).seconds_until_end_of_day, "after DST end"
    end
  end

  def test_sec_fraction
    time = Time.utc(2016, 4, 23, 0, 0, Rational(1, 1_000_000_000))
    assert_equal Rational(1, 1_000_000_000), time.sec_fraction

    time = Time.utc(2016, 4, 23, 0, 0, 0.000_000_001)
    assert_kind_of Rational, time.sec_fraction
    assert_equal 0.000_000_001, time.sec_fraction.to_f

    time = Time.utc(2016, 4, 23, 0, 0, 0, Rational(1, 1_000))
    assert_equal Rational(1, 1_000_000_000), time.sec_fraction

    time = Time.utc(2016, 4, 23, 0, 0, 0, 0.001)
    assert_kind_of Rational, time.sec_fraction
    assert_equal 0.001.to_r / 1000000, time.sec_fraction.to_f
  end

  def test_beginning_of_day
    assert_equal Time.local(2005, 2, 4, 0, 0, 0), Time.local(2005, 2, 4, 10, 10, 10).beginning_of_day
    with_env_tz "US/Eastern" do
      assert_equal Time.local(2006, 4, 2, 0, 0, 0), Time.local(2006, 4, 2, 10, 10, 10).beginning_of_day, "start DST"
      assert_equal Time.local(2006, 10, 29, 0, 0, 0), Time.local(2006, 10, 29, 10, 10, 10).beginning_of_day, "ends DST"
    end
    with_env_tz "NZ" do
      assert_equal Time.local(2006, 3, 19, 0, 0, 0), Time.local(2006, 3, 19, 10, 10, 10).beginning_of_day, "ends DST"
      assert_equal Time.local(2006, 10, 1, 0, 0, 0), Time.local(2006, 10, 1, 10, 10, 10).beginning_of_day, "start DST"
    end
  end

  def test_middle_of_day
    assert_equal Time.local(2005, 2, 4, 12, 0, 0), Time.local(2005, 2, 4, 10, 10, 10).middle_of_day
    with_env_tz "US/Eastern" do
      assert_equal Time.local(2006, 4, 2, 12, 0, 0), Time.local(2006, 4, 2, 10, 10, 10).middle_of_day, "start DST"
      assert_equal Time.local(2006, 10, 29, 12, 0, 0), Time.local(2006, 10, 29, 10, 10, 10).middle_of_day, "ends DST"
    end
    with_env_tz "NZ" do
      assert_equal Time.local(2006, 3, 19, 12, 0, 0), Time.local(2006, 3, 19, 10, 10, 10).middle_of_day, "ends DST"
      assert_equal Time.local(2006, 10, 1, 12, 0, 0), Time.local(2006, 10, 1, 10, 10, 10).middle_of_day, "start DST"
    end
  end

  def test_beginning_of_hour
    assert_equal Time.local(2005, 2, 4, 19, 0, 0), Time.local(2005, 2, 4, 19, 30, 10).beginning_of_hour
  end

  def test_beginning_of_minute
    assert_equal Time.local(2005, 2, 4, 19, 30, 0), Time.local(2005, 2, 4, 19, 30, 10).beginning_of_minute
  end

  def test_end_of_day
    assert_equal Time.local(2007, 8, 12, 23, 59, 59, Rational(999999999, 1000)), Time.local(2007, 8, 12, 10, 10, 10).end_of_day
    with_env_tz "US/Eastern" do
      assert_equal Time.local(2007, 4, 2, 23, 59, 59, Rational(999999999, 1000)), Time.local(2007, 4, 2, 10, 10, 10).end_of_day, "start DST"
      assert_equal Time.local(2007, 10, 29, 23, 59, 59, Rational(999999999, 1000)), Time.local(2007, 10, 29, 10, 10, 10).end_of_day, "ends DST"
    end
    with_env_tz "NZ" do
      assert_equal Time.local(2006, 3, 19, 23, 59, 59, Rational(999999999, 1000)), Time.local(2006, 3, 19, 10, 10, 10).end_of_day, "ends DST"
      assert_equal Time.local(2006, 10, 1, 23, 59, 59, Rational(999999999, 1000)), Time.local(2006, 10, 1, 10, 10, 10).end_of_day, "start DST"
    end
    with_env_tz "Asia/Yekaterinburg" do
      assert_equal Time.local(2015, 2, 8, 23, 59, 59, Rational(999999999, 1000)), Time.new(2015, 2, 8, 8, 0, 0, "+05:00").end_of_day
    end
  end

  def test_end_of_hour
    assert_equal Time.local(2005, 2, 4, 19, 59, 59, Rational(999999999, 1000)), Time.local(2005, 2, 4, 19, 30, 10).end_of_hour
  end

  def test_end_of_minute
    assert_equal Time.local(2005, 2, 4, 19, 30, 59, Rational(999999999, 1000)), Time.local(2005, 2, 4, 19, 30, 10).end_of_minute
  end

  def test_ago
    assert_equal Time.local(2005, 2, 22, 10, 10, 9),  Time.local(2005, 2, 22, 10, 10, 10).ago(1)
    assert_equal Time.local(2005, 2, 22, 9, 10, 10),  Time.local(2005, 2, 22, 10, 10, 10).ago(3600)
    assert_equal Time.local(2005, 2, 20, 10, 10, 10), Time.local(2005, 2, 22, 10, 10, 10).ago(86400 * 2)
    assert_equal Time.local(2005, 2, 20, 9, 9, 45),   Time.local(2005, 2, 22, 10, 10, 10).ago(86400 * 2 + 3600 + 25)
  end

  def test_daylight_savings_time_crossings_backward_start
    with_env_tz "US/Eastern" do
      # dt: US: 2005 April 3rd 4:18am
      assert_equal Time.local(2005, 4, 2, 3, 18, 0), Time.local(2005, 4, 3, 4, 18, 0).ago(24.hours), "dt-24.hours=>st"
      assert_equal Time.local(2005, 4, 2, 3, 18, 0), Time.local(2005, 4, 3, 4, 18, 0).ago(86400), "dt-86400=>st"
      assert_equal Time.local(2005, 4, 2, 3, 18, 0), Time.local(2005, 4, 3, 4, 18, 0).ago(86400.seconds), "dt-86400.seconds=>st"

      assert_equal Time.local(2005, 4, 1, 4, 18, 0), Time.local(2005, 4, 2, 4, 18, 0).ago(24.hours), "st-24.hours=>st"
      assert_equal Time.local(2005, 4, 1, 4, 18, 0), Time.local(2005, 4, 2, 4, 18, 0).ago(86400), "st-86400=>st"
      assert_equal Time.local(2005, 4, 1, 4, 18, 0), Time.local(2005, 4, 2, 4, 18, 0).ago(86400.seconds), "st-86400.seconds=>st"
    end
    with_env_tz "NZ" do
      # dt: New Zealand: 2006 October 1st 4:18am
      assert_equal Time.local(2006, 9, 30, 3, 18, 0), Time.local(2006, 10, 1, 4, 18, 0).ago(24.hours), "dt-24.hours=>st"
      assert_equal Time.local(2006, 9, 30, 3, 18, 0), Time.local(2006, 10, 1, 4, 18, 0).ago(86400), "dt-86400=>st"
      assert_equal Time.local(2006, 9, 30, 3, 18, 0), Time.local(2006, 10, 1, 4, 18, 0).ago(86400.seconds), "dt-86400.seconds=>st"

      assert_equal Time.local(2006, 9, 29, 4, 18, 0), Time.local(2006, 9, 30, 4, 18, 0).ago(24.hours), "st-24.hours=>st"
      assert_equal Time.local(2006, 9, 29, 4, 18, 0), Time.local(2006, 9, 30, 4, 18, 0).ago(86400), "st-86400=>st"
      assert_equal Time.local(2006, 9, 29, 4, 18, 0), Time.local(2006, 9, 30, 4, 18, 0).ago(86400.seconds), "st-86400.seconds=>st"
    end
  end

  def test_daylight_savings_time_crossings_backward_end
    with_env_tz "US/Eastern" do
      # st: US: 2005 October 30th 4:03am
      assert_equal Time.local(2005, 10, 29, 5, 3), Time.local(2005, 10, 30, 4, 3, 0).ago(24.hours), "st-24.hours=>dt"
      assert_equal Time.local(2005, 10, 29, 5, 3), Time.local(2005, 10, 30, 4, 3, 0).ago(86400), "st-86400=>dt"
      assert_equal Time.local(2005, 10, 29, 5, 3), Time.local(2005, 10, 30, 4, 3, 0).ago(86400.seconds), "st-86400.seconds=>dt"

      assert_equal Time.local(2005, 10, 28, 4, 3), Time.local(2005, 10, 29, 4, 3, 0).ago(24.hours), "dt-24.hours=>dt"
      assert_equal Time.local(2005, 10, 28, 4, 3), Time.local(2005, 10, 29, 4, 3, 0).ago(86400), "dt-86400=>dt"
      assert_equal Time.local(2005, 10, 28, 4, 3), Time.local(2005, 10, 29, 4, 3, 0).ago(86400.seconds), "dt-86400.seconds=>dt"
    end
    with_env_tz "NZ" do
      # st: New Zealand: 2006 March 19th 4:03am
      assert_equal Time.local(2006, 3, 18, 5, 3), Time.local(2006, 3, 19, 4, 3, 0).ago(24.hours), "st-24.hours=>dt"
      assert_equal Time.local(2006, 3, 18, 5, 3), Time.local(2006, 3, 19, 4, 3, 0).ago(86400), "st-86400=>dt"
      assert_equal Time.local(2006, 3, 18, 5, 3), Time.local(2006, 3, 19, 4, 3, 0).ago(86400.seconds), "st-86400.seconds=>dt"

      assert_equal Time.local(2006, 3, 17, 4, 3), Time.local(2006, 3, 18, 4, 3, 0).ago(24.hours), "dt-24.hours=>dt"
      assert_equal Time.local(2006, 3, 17, 4, 3), Time.local(2006, 3, 18, 4, 3, 0).ago(86400), "dt-86400=>dt"
      assert_equal Time.local(2006, 3, 17, 4, 3), Time.local(2006, 3, 18, 4, 3, 0).ago(86400.seconds), "dt-86400.seconds=>dt"
    end
  end

  def test_daylight_savings_time_crossings_backward_start_1day
    with_env_tz "US/Eastern" do
      # dt: US: 2005 April 3rd 4:18am
      assert_equal Time.local(2005, 4, 2, 4, 18, 0), Time.local(2005, 4, 3, 4, 18, 0).ago(1.day), "dt-1.day=>st"
      assert_equal Time.local(2005, 4, 1, 4, 18, 0), Time.local(2005, 4, 2, 4, 18, 0).ago(1.day), "st-1.day=>st"
    end
    with_env_tz "NZ" do
      # dt: New Zealand: 2006 October 1st 4:18am
      assert_equal Time.local(2006, 9, 30, 4, 18, 0), Time.local(2006, 10, 1, 4, 18, 0).ago(1.day), "dt-1.day=>st"
      assert_equal Time.local(2006, 9, 29, 4, 18, 0), Time.local(2006, 9, 30, 4, 18, 0).ago(1.day), "st-1.day=>st"
    end
  end

  def test_daylight_savings_time_crossings_backward_end_1day
    with_env_tz "US/Eastern" do
      # st: US: 2005 October 30th 4:03am
      assert_equal Time.local(2005, 10, 29, 4, 3), Time.local(2005, 10, 30, 4, 3, 0).ago(1.day), "st-1.day=>dt"
      assert_equal Time.local(2005, 10, 28, 4, 3), Time.local(2005, 10, 29, 4, 3, 0).ago(1.day), "dt-1.day=>dt"
    end
    with_env_tz "NZ" do
      # st: New Zealand: 2006 March 19th 4:03am
      assert_equal Time.local(2006, 3, 18, 4, 3), Time.local(2006, 3, 19, 4, 3, 0).ago(1.day), "st-1.day=>dt"
      assert_equal Time.local(2006, 3, 17, 4, 3), Time.local(2006, 3, 18, 4, 3, 0).ago(1.day), "dt-1.day=>dt"
    end
  end

  def test_since
    assert_equal Time.local(2005, 2, 22, 10, 10, 11), Time.local(2005, 2, 22, 10, 10, 10).since(1)
    assert_equal Time.local(2005, 2, 22, 11, 10, 10), Time.local(2005, 2, 22, 10, 10, 10).since(3600)
    assert_equal Time.local(2005, 2, 24, 10, 10, 10), Time.local(2005, 2, 22, 10, 10, 10).since(86400 * 2)
    assert_equal Time.local(2005, 2, 24, 11, 10, 35), Time.local(2005, 2, 22, 10, 10, 10).since(86400 * 2 + 3600 + 25)
    # when out of range of Time, returns a DateTime
    assert_equal DateTime.civil(2038, 1, 20, 11, 59, 59), Time.utc(2038, 1, 18, 11, 59, 59).since(86400 * 2)
  end

  def test_daylight_savings_time_crossings_forward_start
    with_env_tz "US/Eastern" do
      # st: US: 2005 April 2nd 7:27pm
      assert_equal Time.local(2005, 4, 3, 20, 27, 0), Time.local(2005, 4, 2, 19, 27, 0).since(24.hours), "st+24.hours=>dt"
      assert_equal Time.local(2005, 4, 3, 20, 27, 0), Time.local(2005, 4, 2, 19, 27, 0).since(86400), "st+86400=>dt"
      assert_equal Time.local(2005, 4, 3, 20, 27, 0), Time.local(2005, 4, 2, 19, 27, 0).since(86400.seconds), "st+86400.seconds=>dt"

      assert_equal Time.local(2005, 4, 4, 19, 27, 0), Time.local(2005, 4, 3, 19, 27, 0).since(24.hours), "dt+24.hours=>dt"
      assert_equal Time.local(2005, 4, 4, 19, 27, 0), Time.local(2005, 4, 3, 19, 27, 0).since(86400), "dt+86400=>dt"
      assert_equal Time.local(2005, 4, 4, 19, 27, 0), Time.local(2005, 4, 3, 19, 27, 0).since(86400.seconds), "dt+86400.seconds=>dt"
    end
    with_env_tz "NZ" do
      # st: New Zealand: 2006 September 30th 7:27pm
      assert_equal Time.local(2006, 10, 1, 20, 27, 0), Time.local(2006, 9, 30, 19, 27, 0).since(24.hours), "st+24.hours=>dt"
      assert_equal Time.local(2006, 10, 1, 20, 27, 0), Time.local(2006, 9, 30, 19, 27, 0).since(86400), "st+86400=>dt"
      assert_equal Time.local(2006, 10, 1, 20, 27, 0), Time.local(2006, 9, 30, 19, 27, 0).since(86400.seconds), "st+86400.seconds=>dt"

      assert_equal Time.local(2006, 10, 2, 19, 27, 0), Time.local(2006, 10, 1, 19, 27, 0).since(24.hours), "dt+24.hours=>dt"
      assert_equal Time.local(2006, 10, 2, 19, 27, 0), Time.local(2006, 10, 1, 19, 27, 0).since(86400), "dt+86400=>dt"
      assert_equal Time.local(2006, 10, 2, 19, 27, 0), Time.local(2006, 10, 1, 19, 27, 0).since(86400.seconds), "dt+86400.seconds=>dt"
    end
  end

  def test_daylight_savings_time_crossings_forward_start_1day
    with_env_tz "US/Eastern" do
      # st: US: 2005 April 2nd 7:27pm
      assert_equal Time.local(2005, 4, 3, 19, 27, 0), Time.local(2005, 4, 2, 19, 27, 0).since(1.day), "st+1.day=>dt"
      assert_equal Time.local(2005, 4, 4, 19, 27, 0), Time.local(2005, 4, 3, 19, 27, 0).since(1.day), "dt+1.day=>dt"
    end
    with_env_tz "NZ" do
      # st: New Zealand: 2006 September 30th 7:27pm
      assert_equal Time.local(2006, 10, 1, 19, 27, 0), Time.local(2006, 9, 30, 19, 27, 0).since(1.day), "st+1.day=>dt"
      assert_equal Time.local(2006, 10, 2, 19, 27, 0), Time.local(2006, 10, 1, 19, 27, 0).since(1.day), "dt+1.day=>dt"
    end
  end

  def test_daylight_savings_time_crossings_forward_start_tomorrow
    with_env_tz "US/Eastern" do
      # st: US: 2005 April 2nd 7:27pm
      assert_equal Time.local(2005, 4, 3, 19, 27, 0), Time.local(2005, 4, 2, 19, 27, 0).tomorrow, "st+1.day=>dt"
      assert_equal Time.local(2005, 4, 4, 19, 27, 0), Time.local(2005, 4, 3, 19, 27, 0).tomorrow, "dt+1.day=>dt"
    end
    with_env_tz "NZ" do
      # st: New Zealand: 2006 September 30th 7:27pm
      assert_equal Time.local(2006, 10, 1, 19, 27, 0), Time.local(2006, 9, 30, 19, 27, 0).tomorrow, "st+1.day=>dt"
      assert_equal Time.local(2006, 10, 2, 19, 27, 0), Time.local(2006, 10, 1, 19, 27, 0).tomorrow, "dt+1.day=>dt"
    end
  end

  def test_daylight_savings_time_crossings_backward_start_yesterday
    with_env_tz "US/Eastern" do
      # st: US: 2005 April 2nd 7:27pm
      assert_equal Time.local(2005, 4, 2, 19, 27, 0), Time.local(2005, 4, 3, 19, 27, 0).yesterday, "dt-1.day=>st"
      assert_equal Time.local(2005, 4, 3, 19, 27, 0), Time.local(2005, 4, 4, 19, 27, 0).yesterday, "dt-1.day=>dt"
    end
    with_env_tz "NZ" do
      # st: New Zealand: 2006 September 30th 7:27pm
      assert_equal Time.local(2006, 9, 30, 19, 27, 0), Time.local(2006, 10, 1, 19, 27, 0).yesterday, "dt-1.day=>st"
      assert_equal Time.local(2006, 10, 1, 19, 27, 0), Time.local(2006, 10, 2, 19, 27, 0).yesterday, "dt-1.day=>dt"
    end
  end

  def test_daylight_savings_time_crossings_forward_end
    with_env_tz "US/Eastern" do
      # dt: US: 2005 October 30th 12:45am
      assert_equal Time.local(2005, 10, 30, 23, 45, 0), Time.local(2005, 10, 30, 0, 45, 0).since(24.hours), "dt+24.hours=>st"
      assert_equal Time.local(2005, 10, 30, 23, 45, 0), Time.local(2005, 10, 30, 0, 45, 0).since(86400), "dt+86400=>st"
      assert_equal Time.local(2005, 10, 30, 23, 45, 0), Time.local(2005, 10, 30, 0, 45, 0).since(86400.seconds), "dt+86400.seconds=>st"

      assert_equal Time.local(2005, 11, 1, 0, 45, 0), Time.local(2005, 10, 31, 0, 45, 0).since(24.hours), "st+24.hours=>st"
      assert_equal Time.local(2005, 11, 1, 0, 45, 0), Time.local(2005, 10, 31, 0, 45, 0).since(86400), "st+86400=>st"
      assert_equal Time.local(2005, 11, 1, 0, 45, 0), Time.local(2005, 10, 31, 0, 45, 0).since(86400.seconds), "st+86400.seconds=>st"
    end
    with_env_tz "NZ" do
      # dt: New Zealand: 2006 March 19th 1:45am
      assert_equal Time.local(2006, 3, 20, 0, 45, 0), Time.local(2006, 3, 19, 1, 45, 0).since(24.hours), "dt+24.hours=>st"
      assert_equal Time.local(2006, 3, 20, 0, 45, 0), Time.local(2006, 3, 19, 1, 45, 0).since(86400), "dt+86400=>st"
      assert_equal Time.local(2006, 3, 20, 0, 45, 0), Time.local(2006, 3, 19, 1, 45, 0).since(86400.seconds), "dt+86400.seconds=>st"

      assert_equal Time.local(2006, 3, 21, 1, 45, 0), Time.local(2006, 3, 20, 1, 45, 0).since(24.hours), "st+24.hours=>st"
      assert_equal Time.local(2006, 3, 21, 1, 45, 0), Time.local(2006, 3, 20, 1, 45, 0).since(86400), "st+86400=>st"
      assert_equal Time.local(2006, 3, 21, 1, 45, 0), Time.local(2006, 3, 20, 1, 45, 0).since(86400.seconds), "st+86400.seconds=>st"
    end
  end

  def test_daylight_savings_time_crossings_forward_end_1day
    with_env_tz "US/Eastern" do
      # dt: US: 2005 October 30th 12:45am
      assert_equal Time.local(2005, 10, 31, 0, 45, 0), Time.local(2005, 10, 30, 0, 45, 0).since(1.day), "dt+1.day=>st"
      assert_equal Time.local(2005, 11, 1, 0, 45, 0), Time.local(2005, 10, 31, 0, 45, 0).since(1.day), "st+1.day=>st"
    end
    with_env_tz "NZ" do
      # dt: New Zealand: 2006 March 19th 1:45am
      assert_equal Time.local(2006, 3, 20, 1, 45, 0), Time.local(2006, 3, 19, 1, 45, 0).since(1.day), "dt+1.day=>st"
      assert_equal Time.local(2006, 3, 21, 1, 45, 0), Time.local(2006, 3, 20, 1, 45, 0).since(1.day), "st+1.day=>st"
    end
  end

  def test_daylight_savings_time_crossings_forward_end_tomorrow
    with_env_tz "US/Eastern" do
      # dt: US: 2005 October 30th 12:45am
      assert_equal Time.local(2005, 10, 31, 0, 45, 0), Time.local(2005, 10, 30, 0, 45, 0).tomorrow, "dt+1.day=>st"
      assert_equal Time.local(2005, 11, 1, 0, 45, 0), Time.local(2005, 10, 31, 0, 45, 0).tomorrow, "st+1.day=>st"
    end
    with_env_tz "NZ" do
      # dt: New Zealand: 2006 March 19th 1:45am
      assert_equal Time.local(2006, 3, 20, 1, 45, 0), Time.local(2006, 3, 19, 1, 45, 0).tomorrow, "dt+1.day=>st"
      assert_equal Time.local(2006, 3, 21, 1, 45, 0), Time.local(2006, 3, 20, 1, 45, 0).tomorrow, "st+1.day=>st"
    end
  end

  def test_daylight_savings_time_crossings_backward_end_yesterday
    with_env_tz "US/Eastern" do
      # dt: US: 2005 October 30th 12:45am
      assert_equal Time.local(2005, 10, 30, 0, 45, 0), Time.local(2005, 10, 31, 0, 45, 0).yesterday, "st-1.day=>dt"
      assert_equal Time.local(2005, 10, 31, 0, 45, 0), Time.local(2005, 11, 1, 0, 45, 0).yesterday, "st-1.day=>st"
    end
    with_env_tz "NZ" do
      # dt: New Zealand: 2006 March 19th 1:45am
      assert_equal Time.local(2006, 3, 19, 1, 45, 0), Time.local(2006, 3, 20, 1, 45, 0).yesterday, "st-1.day=>dt"
      assert_equal Time.local(2006, 3, 20, 1, 45, 0), Time.local(2006, 3, 21, 1, 45, 0).yesterday, "st-1.day=>st"
    end
  end

  def test_change
    assert_equal Time.local(2006, 2, 22, 15, 15, 10), Time.local(2005, 2, 22, 15, 15, 10).change(year: 2006)
    assert_equal Time.local(2005, 6, 22, 15, 15, 10), Time.local(2005, 2, 22, 15, 15, 10).change(month: 6)
    assert_equal Time.local(2012, 9, 22, 15, 15, 10), Time.local(2005, 2, 22, 15, 15, 10).change(year: 2012, month: 9)
    assert_equal Time.local(2005, 2, 22, 16),       Time.local(2005, 2, 22, 15, 15, 10).change(hour: 16)
    assert_equal Time.local(2005, 2, 22, 16, 45),    Time.local(2005, 2, 22, 15, 15, 10).change(hour: 16, min: 45)
    assert_equal Time.local(2005, 2, 22, 15, 45),    Time.local(2005, 2, 22, 15, 15, 10).change(min: 45)

    assert_equal Time.local(2005, 1, 2, 5, 0, 0, 0), Time.local(2005, 1, 2, 11, 22, 33, 44).change(hour: 5)
    assert_equal Time.local(2005, 1, 2, 11, 6, 0, 0), Time.local(2005, 1, 2, 11, 22, 33, 44).change(min: 6)
    assert_equal Time.local(2005, 1, 2, 11, 22, 7, 0), Time.local(2005, 1, 2, 11, 22, 33, 44).change(sec: 7)
    assert_equal Time.local(2005, 1, 2, 11, 22, 33, 8), Time.local(2005, 1, 2, 11, 22, 33, 44).change(usec: 8)
    assert_equal Time.local(2005, 1, 2, 11, 22, 33, 8), Time.local(2005, 1, 2, 11, 22, 33, 2).change(nsec: 8000)
    assert_raise(ArgumentError) { Time.local(2005, 1, 2, 11, 22, 33, 8).change(usec: 1, nsec: 1) }
    assert_nothing_raised { Time.new(2015, 5, 9, 10, 00, 00, "+03:00").change(nsec: 999999999) }
  end

  def test_utc_change
    assert_equal Time.utc(2006, 2, 22, 15, 15, 10), Time.utc(2005, 2, 22, 15, 15, 10).change(year: 2006)
    assert_equal Time.utc(2005, 6, 22, 15, 15, 10), Time.utc(2005, 2, 22, 15, 15, 10).change(month: 6)
    assert_equal Time.utc(2012, 9, 22, 15, 15, 10), Time.utc(2005, 2, 22, 15, 15, 10).change(year: 2012, month: 9)
    assert_equal Time.utc(2005, 2, 22, 16),       Time.utc(2005, 2, 22, 15, 15, 10).change(hour: 16)
    assert_equal Time.utc(2005, 2, 22, 16, 45),    Time.utc(2005, 2, 22, 15, 15, 10).change(hour: 16, min: 45)
    assert_equal Time.utc(2005, 2, 22, 15, 45),    Time.utc(2005, 2, 22, 15, 15, 10).change(min: 45)
    assert_equal Time.utc(2005, 1, 2, 11, 22, 33, 8), Time.utc(2005, 1, 2, 11, 22, 33, 2).change(nsec: 8000)
  end

  def test_offset_change
    assert_equal Time.new(2006, 2, 22, 15, 15, 10, "-08:00"), Time.new(2005, 2, 22, 15, 15, 10, "-08:00").change(year: 2006)
    assert_equal Time.new(2005, 6, 22, 15, 15, 10, "-08:00"), Time.new(2005, 2, 22, 15, 15, 10, "-08:00").change(month: 6)
    assert_equal Time.new(2012, 9, 22, 15, 15, 10, "-08:00"), Time.new(2005, 2, 22, 15, 15, 10, "-08:00").change(year: 2012, month: 9)
    assert_equal Time.new(2005, 2, 22, 16, 0, 0, "-08:00"),   Time.new(2005, 2, 22, 15, 15, 10, "-08:00").change(hour: 16)
    assert_equal Time.new(2005, 2, 22, 16, 45, 0, "-08:00"),  Time.new(2005, 2, 22, 15, 15, 10, "-08:00").change(hour: 16, min: 45)
    assert_equal Time.new(2005, 2, 22, 15, 45, 0, "-08:00"),  Time.new(2005, 2, 22, 15, 15, 10, "-08:00").change(min: 45)
    assert_equal Time.new(2005, 2, 22, 15, 15, 10, "-08:00"),  Time.new(2005, 2, 22, 15, 15, 0, "-08:00").change(sec: 10)
    assert_equal 10, Time.new(2005, 2, 22, 15, 15, 0, "-08:00").change(usec: 10).usec
    assert_equal 10, Time.new(2005, 2, 22, 15, 15, 0, "-08:00").change(nsec: 10).nsec
    assert_raise(ArgumentError) { Time.new(2005, 2, 22, 15, 15, 45, "-08:00").change(usec: 1000000) }
    assert_raise(ArgumentError) { Time.new(2005, 2, 22, 15, 15, 45, "-08:00").change(nsec: 1000000000) }
  end

  def test_change_offset
    assert_equal Time.new(2006, 2, 22, 15, 15, 10, "-08:00"), Time.new(2006, 2, 22, 15, 15, 10, "+01:00").change(offset: "-08:00")
    assert_equal Time.new(2006, 2, 22, 15, 15, 10, -28800), Time.new(2006, 2, 22, 15, 15, 10, 3600).change(offset: -28800)
    assert_raise(ArgumentError) { Time.new(2005, 2, 22, 15, 15, 45, "+01:00").change(usec: 1000000, offset: "-08:00") }
    assert_raise(ArgumentError) { Time.new(2005, 2, 22, 15, 15, 45, "+01:00").change(nsec: 1000000000, offset: -28800) }
  end

  def test_advance
    assert_equal Time.local(2006, 2, 28, 15, 15, 10), Time.local(2005, 2, 28, 15, 15, 10).advance(years: 1)
    assert_equal Time.local(2005, 6, 28, 15, 15, 10), Time.local(2005, 2, 28, 15, 15, 10).advance(months: 4)
    assert_equal Time.local(2005, 3, 21, 15, 15, 10), Time.local(2005, 2, 28, 15, 15, 10).advance(weeks: 3)
    assert_equal Time.local(2005, 3, 25, 3, 15, 10), Time.local(2005, 2, 28, 15, 15, 10).advance(weeks: 3.5)
    assert_in_delta Time.local(2005, 3, 26, 12, 51, 10), Time.local(2005, 2, 28, 15, 15, 10).advance(weeks: 3.7), 1
    assert_equal Time.local(2005, 3, 5, 15, 15, 10), Time.local(2005, 2, 28, 15, 15, 10).advance(days: 5)
    assert_equal Time.local(2005, 3, 6, 3, 15, 10), Time.local(2005, 2, 28, 15, 15, 10).advance(days: 5.5)
    assert_in_delta Time.local(2005, 3, 6, 8, 3, 10), Time.local(2005, 2, 28, 15, 15, 10).advance(days: 5.7), 1
    assert_equal Time.local(2012, 9, 28, 15, 15, 10), Time.local(2005, 2, 28, 15, 15, 10).advance(years: 7, months: 7)
    assert_equal Time.local(2013, 10, 3, 15, 15, 10), Time.local(2005, 2, 28, 15, 15, 10).advance(years: 7, months: 19, days: 5)
    assert_equal Time.local(2013, 10, 17, 15, 15, 10), Time.local(2005, 2, 28, 15, 15, 10).advance(years: 7, months: 19, weeks: 2, days: 5)
    assert_equal Time.local(2001, 12, 27, 15, 15, 10), Time.local(2005, 2, 28, 15, 15, 10).advance(years: -3, months: -2, days: -1)
    assert_equal Time.local(2005, 2, 28, 15, 15, 10), Time.local(2004, 2, 29, 15, 15, 10).advance(years: 1) # leap day plus one year
    assert_equal Time.local(2005, 2, 28, 20, 15, 10), Time.local(2005, 2, 28, 15, 15, 10).advance(hours: 5)
    assert_equal Time.local(2005, 2, 28, 15, 22, 10), Time.local(2005, 2, 28, 15, 15, 10).advance(minutes: 7)
    assert_equal Time.local(2005, 2, 28, 15, 15, 19), Time.local(2005, 2, 28, 15, 15, 10).advance(seconds: 9)
    assert_equal Time.local(2005, 2, 28, 20, 22, 19), Time.local(2005, 2, 28, 15, 15, 10).advance(hours: 5, minutes: 7, seconds: 9)
    assert_equal Time.local(2005, 2, 28, 10, 8, 1), Time.local(2005, 2, 28, 15, 15, 10).advance(hours: -5, minutes: -7, seconds: -9)
    assert_equal Time.local(2013, 10, 17, 20, 22, 19), Time.local(2005, 2, 28, 15, 15, 10).advance(years: 7, months: 19, weeks: 2, days: 5, hours: 5, minutes: 7, seconds: 9)
  end

  def test_utc_advance
    assert_equal Time.utc(2006, 2, 22, 15, 15, 10), Time.utc(2005, 2, 22, 15, 15, 10).advance(years: 1)
    assert_equal Time.utc(2005, 6, 22, 15, 15, 10), Time.utc(2005, 2, 22, 15, 15, 10).advance(months: 4)
    assert_equal Time.utc(2005, 3, 21, 15, 15, 10), Time.utc(2005, 2, 28, 15, 15, 10).advance(weeks: 3)
    assert_equal Time.utc(2005, 3, 25, 3, 15, 10), Time.utc(2005, 2, 28, 15, 15, 10).advance(weeks: 3.5)
    assert_in_delta Time.utc(2005, 3, 26, 12, 51, 10), Time.utc(2005, 2, 28, 15, 15, 10).advance(weeks: 3.7), 1
    assert_equal Time.utc(2005, 3, 5, 15, 15, 10), Time.utc(2005, 2, 28, 15, 15, 10).advance(days: 5)
    assert_equal Time.utc(2005, 3, 6, 3, 15, 10), Time.utc(2005, 2, 28, 15, 15, 10).advance(days: 5.5)
    assert_in_delta Time.utc(2005, 3, 6, 8, 3, 10), Time.utc(2005, 2, 28, 15, 15, 10).advance(days: 5.7), 1
    assert_equal Time.utc(2012, 9, 22, 15, 15, 10), Time.utc(2005, 2, 22, 15, 15, 10).advance(years: 7, months: 7)
    assert_equal Time.utc(2013, 10, 3, 15, 15, 10), Time.utc(2005, 2, 22, 15, 15, 10).advance(years: 7, months: 19, days: 11)
    assert_equal Time.utc(2013, 10, 17, 15, 15, 10), Time.utc(2005, 2, 28, 15, 15, 10).advance(years: 7, months: 19, weeks: 2, days: 5)
    assert_equal Time.utc(2001, 12, 27, 15, 15, 10), Time.utc(2005, 2, 28, 15, 15, 10).advance(years: -3, months: -2, days: -1)
    assert_equal Time.utc(2005, 2, 28, 15, 15, 10), Time.utc(2004, 2, 29, 15, 15, 10).advance(years: 1) # leap day plus one year
    assert_equal Time.utc(2005, 2, 28, 20, 15, 10), Time.utc(2005, 2, 28, 15, 15, 10).advance(hours: 5)
    assert_equal Time.utc(2005, 2, 28, 15, 22, 10), Time.utc(2005, 2, 28, 15, 15, 10).advance(minutes: 7)
    assert_equal Time.utc(2005, 2, 28, 15, 15, 19), Time.utc(2005, 2, 28, 15, 15, 10).advance(seconds: 9)
    assert_equal Time.utc(2005, 2, 28, 20, 22, 19), Time.utc(2005, 2, 28, 15, 15, 10).advance(hours: 5, minutes: 7, seconds: 9)
    assert_equal Time.utc(2005, 2, 28, 10, 8, 1), Time.utc(2005, 2, 28, 15, 15, 10).advance(hours: -5, minutes: -7, seconds: -9)
    assert_equal Time.utc(2013, 10, 17, 20, 22, 19), Time.utc(2005, 2, 28, 15, 15, 10).advance(years: 7, months: 19, weeks: 2, days: 5, hours: 5, minutes: 7, seconds: 9)
  end

  def test_offset_advance
    assert_equal Time.new(2006, 2, 22, 15, 15, 10, "-08:00"), Time.new(2005, 2, 22, 15, 15, 10, "-08:00").advance(years: 1)
    assert_equal Time.new(2005, 6, 22, 15, 15, 10, "-08:00"), Time.new(2005, 2, 22, 15, 15, 10, "-08:00").advance(months: 4)
    assert_equal Time.new(2005, 3, 21, 15, 15, 10, "-08:00"), Time.new(2005, 2, 28, 15, 15, 10, "-08:00").advance(weeks: 3)
    assert_equal Time.new(2005, 3, 25, 3, 15, 10, "-08:00"), Time.new(2005, 2, 28, 15, 15, 10, "-08:00").advance(weeks: 3.5)
    assert_in_delta Time.new(2005, 3, 26, 12, 51, 10, "-08:00"), Time.new(2005, 2, 28, 15, 15, 10, "-08:00").advance(weeks: 3.7), 1
    assert_equal Time.new(2005, 3, 5, 15, 15, 10, "-08:00"), Time.new(2005, 2, 28, 15, 15, 10, "-08:00").advance(days: 5)
    assert_equal Time.new(2005, 3, 6, 3, 15, 10, "-08:00"), Time.new(2005, 2, 28, 15, 15, 10, "-08:00").advance(days: 5.5)
    assert_in_delta Time.new(2005, 3, 6, 8, 3, 10, "-08:00"), Time.new(2005, 2, 28, 15, 15, 10, "-08:00").advance(days: 5.7), 1
    assert_equal Time.new(2012, 9, 22, 15, 15, 10, "-08:00"), Time.new(2005, 2, 22, 15, 15, 10, "-08:00").advance(years: 7, months: 7)
    assert_equal Time.new(2013, 10, 3, 15, 15, 10, "-08:00"), Time.new(2005, 2, 22, 15, 15, 10, "-08:00").advance(years: 7, months: 19, days: 11)
    assert_equal Time.new(2013, 10, 17, 15, 15, 10, "-08:00"), Time.new(2005, 2, 28, 15, 15, 10, "-08:00").advance(years: 7, months: 19, weeks: 2, days: 5)
    assert_equal Time.new(2001, 12, 27, 15, 15, 10, "-08:00"), Time.new(2005, 2, 28, 15, 15, 10, "-08:00").advance(years: -3, months: -2, days: -1)
    assert_equal Time.new(2005, 2, 28, 15, 15, 10, "-08:00"), Time.new(2004, 2, 29, 15, 15, 10, "-08:00").advance(years: 1) # leap day plus one year
    assert_equal Time.new(2005, 2, 28, 20, 15, 10, "-08:00"), Time.new(2005, 2, 28, 15, 15, 10, "-08:00").advance(hours: 5)
    assert_equal Time.new(2005, 2, 28, 15, 22, 10, "-08:00"), Time.new(2005, 2, 28, 15, 15, 10, "-08:00").advance(minutes: 7)
    assert_equal Time.new(2005, 2, 28, 15, 15, 19, "-08:00"), Time.new(2005, 2, 28, 15, 15, 10, "-08:00").advance(seconds: 9)
    assert_equal Time.new(2005, 2, 28, 20, 22, 19, "-08:00"), Time.new(2005, 2, 28, 15, 15, 10, "-08:00").advance(hours: 5, minutes: 7, seconds: 9)
    assert_equal Time.new(2005, 2, 28, 10, 8, 1, "-08:00"), Time.new(2005, 2, 28, 15, 15, 10, "-08:00").advance(hours: -5, minutes: -7, seconds: -9)
    assert_equal Time.new(2013, 10, 17, 20, 22, 19, "-08:00"), Time.new(2005, 2, 28, 15, 15, 10, "-08:00").advance(years: 7, months: 19, weeks: 2, days: 5, hours: 5, minutes: 7, seconds: 9)
  end

  def test_advance_with_nsec
    t = Time.at(0, Rational(108635108, 1000))
    assert_equal t, t.advance(months: 0)
  end

  def test_advance_gregorian_proleptic
    assert_equal Time.local(1582, 10, 14, 15, 15, 10), Time.local(1582, 10, 15, 15, 15, 10).advance(days: -1)
    assert_equal Time.local(1582, 10, 15, 15, 15, 10), Time.local(1582, 10, 14, 15, 15, 10).advance(days: 1)
    assert_equal Time.local(1582, 10, 5, 15, 15, 10), Time.local(1582, 10, 4, 15, 15, 10).advance(days: 1)
    assert_equal Time.local(1582, 10, 4, 15, 15, 10), Time.local(1582, 10, 5, 15, 15, 10).advance(days: -1)
    assert_equal Time.local(999, 10, 4, 15, 15, 10), Time.local(1000, 10, 4, 15, 15, 10).advance(years: -1)
    assert_equal Time.local(1000, 10, 4, 15, 15, 10), Time.local(999, 10, 4, 15, 15, 10).advance(years: 1)
  end

  def test_last_week
    with_env_tz "US/Eastern" do
      assert_equal Time.local(2005, 2, 21), Time.local(2005, 3, 1, 15, 15, 10).last_week
      assert_equal Time.local(2005, 2, 22), Time.local(2005, 3, 1, 15, 15, 10).last_week(:tuesday)
      assert_equal Time.local(2005, 2, 25), Time.local(2005, 3, 1, 15, 15, 10).last_week(:friday)
      assert_equal Time.local(2006, 10, 30), Time.local(2006, 11, 6, 0, 0, 0).last_week
      assert_equal Time.local(2006, 11, 15), Time.local(2006, 11, 23, 0, 0, 0).last_week(:wednesday)
    end
  end

  def test_next_week_near_daylight_start
    with_env_tz "US/Eastern" do
      assert_equal Time.local(2006, 4, 3), Time.local(2006, 4, 2, 23, 1, 0).next_week, "just crossed standard => daylight"
    end
    with_env_tz "NZ" do
      assert_equal Time.local(2006, 10, 2), Time.local(2006, 10, 1, 23, 1, 0).next_week, "just crossed standard => daylight"
    end
  end

  def test_next_week_near_daylight_end
    with_env_tz "US/Eastern" do
      assert_equal Time.local(2006, 10, 30), Time.local(2006, 10, 29, 23, 1, 0).next_week, "just crossed daylight => standard"
    end
    with_env_tz "NZ" do
      assert_equal Time.local(2006, 3, 20), Time.local(2006, 3, 19, 23, 1, 0).next_week, "just crossed daylight => standard"
    end
  end

  def test_to_s
    time = Time.utc(2005, 2, 21, 17, 44, 30.12345678901)
    assert_equal time.to_default_s,                 time.to_s
    assert_equal time.to_default_s,                 time.to_s(:doesnt_exist)
    assert_equal "2005-02-21 17:44:30",             time.to_s(:db)
    assert_equal "21 Feb 17:44",                    time.to_s(:short)
    assert_equal "17:44",                           time.to_s(:time)
    assert_equal "20050221174430",                  time.to_s(:number)
    assert_equal "20050221174430123456789",         time.to_s(:nsec)
    assert_equal "20050221174430123456",            time.to_s(:usec)
    assert_equal "February 21, 2005 17:44",         time.to_s(:long)
    assert_equal "February 21st, 2005 17:44",       time.to_s(:long_ordinal)
    with_env_tz "UTC" do
      assert_equal "Mon, 21 Feb 2005 17:44:30 +0000", time.to_s(:rfc822)
      assert_equal "2005-02-21 17:44:30.123456789 +0000", time.to_s(:inspect)
    end
    with_env_tz "US/Central" do
      assert_equal "Thu, 05 Feb 2009 14:30:05 -0600", Time.local(2009, 2, 5, 14, 30, 5).to_s(:rfc822)
      assert_equal "Mon, 09 Jun 2008 04:05:01 -0500", Time.local(2008, 6, 9, 4, 5, 1).to_s(:rfc822)
      assert_equal "2009-02-05T14:30:05-06:00", Time.local(2009, 2, 5, 14, 30, 5).to_s(:iso8601)
      assert_equal "2008-06-09T04:05:01-05:00", Time.local(2008, 6, 9, 4, 5, 1).to_s(:iso8601)
      assert_equal "2009-02-05T14:30:05Z", Time.utc(2009, 2, 5, 14, 30, 5).to_s(:iso8601)
      assert_equal "2009-02-05 14:30:05.000000000 -0600", Time.local(2009, 2, 5, 14, 30, 5).to_s(:inspect)
      assert_equal "2008-06-09 04:05:01.000000000 -0500", Time.local(2008, 6, 9, 4, 5, 1).to_s(:inspect)
    end
  end

  def test_custom_date_format
    Time::DATE_FORMATS[:custom] = "%Y%m%d%H%M%S"
    assert_equal "20050221143000", Time.local(2005, 2, 21, 14, 30, 0).to_s(:custom)
    Time::DATE_FORMATS.delete(:custom)
  end

  def test_rfc3339_with_fractional_seconds
    time = Time.new(1999, 12, 31, 19, 0, Rational(1, 8), -18000)
    assert_equal "1999-12-31T19:00:00.125-05:00", time.rfc3339(3)
  end

  def test_to_date
    assert_equal Date.new(2005, 2, 21), Time.local(2005, 2, 21, 17, 44, 30).to_date
  end

  def test_to_datetime
    assert_equal Time.utc(2005, 2, 21, 17, 44, 30).to_datetime, DateTime.civil(2005, 2, 21, 17, 44, 30, 0)
    with_env_tz "US/Eastern" do
      assert_equal Time.local(2005, 2, 21, 17, 44, 30).to_datetime, DateTime.civil(2005, 2, 21, 17, 44, 30, Rational(Time.local(2005, 2, 21, 17, 44, 30).utc_offset, 86400))
    end
    with_env_tz "NZ" do
      assert_equal Time.local(2005, 2, 21, 17, 44, 30).to_datetime, DateTime.civil(2005, 2, 21, 17, 44, 30, Rational(Time.local(2005, 2, 21, 17, 44, 30).utc_offset, 86400))
    end
    assert_equal ::Date::ITALY, Time.utc(2005, 2, 21, 17, 44, 30).to_datetime.start # use Ruby's default start value
  end

  def test_to_time
    with_env_tz "US/Eastern" do
      assert_equal Time, Time.local(2005, 2, 21, 17, 44, 30).to_time.class
      assert_equal Time.local(2005, 2, 21, 17, 44, 30), Time.local(2005, 2, 21, 17, 44, 30).to_time
      assert_equal Time.local(2005, 2, 21, 17, 44, 30).utc_offset, Time.local(2005, 2, 21, 17, 44, 30).to_time.utc_offset
    end
  end

  # NOTE: this test seems to fail (changeset 1958) only on certain platforms,
  # like OSX, and FreeBSD 5.4.
  def test_fp_inaccuracy_ticket_1836
    midnight = Time.local(2005, 2, 21, 0, 0, 0)
    assert_equal midnight.midnight, (midnight + 1.hour + 0.000001).midnight
  end

  def test_days_in_month_with_year
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

  def test_days_in_month_feb_in_common_year_without_year_arg
    Time.stub(:now, Time.utc(2007)) do
      assert_equal 28, Time.days_in_month(2)
    end
  end

  def test_days_in_month_feb_in_leap_year_without_year_arg
    Time.stub(:now, Time.utc(2008)) do
      assert_equal 29, Time.days_in_month(2)
    end
  end

  def test_days_in_year_with_year
    assert_equal 365, Time.days_in_year(2005)
    assert_equal 366, Time.days_in_year(2004)
    assert_equal 366, Time.days_in_year(2000)
    assert_equal 365, Time.days_in_year(1900)
  end

  def test_days_in_year_in_common_year_without_year_arg
    Time.stub(:now, Time.utc(2007)) do
      assert_equal 365, Time.days_in_year
    end
  end

  def test_days_in_year_in_leap_year_without_year_arg
    Time.stub(:now, Time.utc(2008)) do
      assert_equal 366, Time.days_in_year
    end
  end

  def test_xmlschema_is_available
    assert_nothing_raised { Time.now.xmlschema }
  end

  def test_today_with_time_local
    Date.stub(:current, Date.new(2000, 1, 1)) do
      assert_equal false, Time.local(1999, 12, 31, 23, 59, 59).today?
      assert_equal true,  Time.local(2000, 1, 1, 0).today?
      assert_equal true,  Time.local(2000, 1, 1, 23, 59, 59).today?
      assert_equal false, Time.local(2000, 1, 2, 0).today?
    end
  end

  def test_today_with_time_utc
    Date.stub(:current, Date.new(2000, 1, 1)) do
      assert_equal false, Time.utc(1999, 12, 31, 23, 59, 59).today?
      assert_equal true,  Time.utc(2000, 1, 1, 0).today?
      assert_equal true,  Time.utc(2000, 1, 1, 23, 59, 59).today?
      assert_equal false, Time.utc(2000, 1, 2, 0).today?
    end
  end

  def test_yesterday_with_time_local
    Date.stub(:current, Date.new(2000, 1, 1)) do
      assert_equal true,  Time.local(1999, 12, 31, 23, 59, 59).yesterday?
      assert_equal false, Time.local(2000, 1, 1, 0).yesterday?
      assert_equal true,  Time.local(1999, 12, 31).yesterday?
      assert_equal false, Time.local(2000, 1, 2, 0).yesterday?
    end
  end

  def test_yesterday_with_time_utc
    Date.stub(:current, Date.new(2000, 1, 1)) do
      assert_equal true,  Time.utc(1999, 12, 31, 23, 59, 59).yesterday?
      assert_equal false, Time.utc(2000, 1, 1, 0).yesterday?
      assert_equal true,  Time.utc(1999, 12, 31).yesterday?
      assert_equal false, Time.utc(2000, 1, 2, 0).yesterday?
    end
  end

  def test_prev_day_with_time_local
    Date.stub(:current, Date.new(2000, 1, 1)) do
      assert_equal true,  Time.local(1999, 12, 31, 23, 59, 59).prev_day?
      assert_equal false, Time.local(2000, 1, 1, 0).prev_day?
      assert_equal true,  Time.local(1999, 12, 31).prev_day?
      assert_equal false, Time.local(2000, 1, 2, 0).prev_day?
    end
  end

  def test_prev_day_with_time_utc
    Date.stub(:current, Date.new(2000, 1, 1)) do
      assert_equal true,  Time.utc(1999, 12, 31, 23, 59, 59).prev_day?
      assert_equal false, Time.utc(2000, 1, 1, 0).prev_day?
      assert_equal true,  Time.utc(1999, 12, 31).prev_day?
      assert_equal false, Time.utc(2000, 1, 2, 0).prev_day?
    end
  end

  def test_tomorrow_with_time_local
    Date.stub(:current, Date.new(2000, 1, 1)) do
      assert_equal false, Time.local(1999, 12, 31, 23, 59, 59).tomorrow?
      assert_equal true,  Time.local(2000, 1, 2, 0).tomorrow?
      assert_equal true,  Time.local(2000, 1, 2, 23, 59, 59).tomorrow?
      assert_equal false, Time.local(2000, 1, 1, 0).tomorrow?
    end
  end

  def test_tomorrow_with_time_utc
    Date.stub(:current, Date.new(2000, 1, 1)) do
      assert_equal false, Time.utc(1999, 12, 31, 23, 59, 59).tomorrow?
      assert_equal true,  Time.utc(2000, 1, 2, 0).tomorrow?
      assert_equal true,  Time.utc(2000, 1, 2, 23, 59, 59).tomorrow?
      assert_equal false, Time.utc(2000, 1, 1, 0).tomorrow?
    end
  end

  def test_next_day_with_time_local
    Date.stub(:current, Date.new(2000, 1, 1)) do
      assert_equal false, Time.local(1999, 12, 31, 23, 59, 59).next_day?
      assert_equal true,  Time.local(2000, 1, 2, 0).next_day?
      assert_equal true,  Time.local(2000, 1, 2, 23, 59, 59).next_day?
      assert_equal false, Time.local(2000, 1, 1, 0).next_day?
    end
  end

  def test_next_day_with_time_utc
    Date.stub(:current, Date.new(2000, 1, 1)) do
      assert_equal false, Time.utc(1999, 12, 31, 23, 59, 59).next_day?
      assert_equal true,  Time.utc(2000, 1, 2, 0).next_day?
      assert_equal true,  Time.utc(2000, 1, 2, 23, 59, 59).next_day?
      assert_equal false, Time.utc(2000, 1, 1, 0).next_day?
    end
  end

  def test_past_with_time_current_as_time_local
    with_env_tz "US/Eastern" do
      Time.stub(:current, Time.local(2005, 2, 10, 15, 30, 45)) do
        assert_equal true,  Time.local(2005, 2, 10, 15, 30, 44).past?
        assert_equal false,  Time.local(2005, 2, 10, 15, 30, 45).past?
        assert_equal false,  Time.local(2005, 2, 10, 15, 30, 46).past?
        assert_equal true,  Time.utc(2005, 2, 10, 20, 30, 44).past?
        assert_equal false,  Time.utc(2005, 2, 10, 20, 30, 45).past?
        assert_equal false,  Time.utc(2005, 2, 10, 20, 30, 46).past?
      end
    end
  end

  def test_past_with_time_current_as_time_with_zone
    with_env_tz "US/Eastern" do
      twz = Time.utc(2005, 2, 10, 15, 30, 45).in_time_zone("Central Time (US & Canada)")
      Time.stub(:current, twz) do
        assert_equal true,  Time.local(2005, 2, 10, 10, 30, 44).past?
        assert_equal false,  Time.local(2005, 2, 10, 10, 30, 45).past?
        assert_equal false,  Time.local(2005, 2, 10, 10, 30, 46).past?
        assert_equal true,  Time.utc(2005, 2, 10, 15, 30, 44).past?
        assert_equal false,  Time.utc(2005, 2, 10, 15, 30, 45).past?
        assert_equal false,  Time.utc(2005, 2, 10, 15, 30, 46).past?
      end
    end
  end

  def test_future_with_time_current_as_time_local
    with_env_tz "US/Eastern" do
      Time.stub(:current, Time.local(2005, 2, 10, 15, 30, 45)) do
        assert_equal false,  Time.local(2005, 2, 10, 15, 30, 44).future?
        assert_equal false,  Time.local(2005, 2, 10, 15, 30, 45).future?
        assert_equal true,  Time.local(2005, 2, 10, 15, 30, 46).future?
        assert_equal false,  Time.utc(2005, 2, 10, 20, 30, 44).future?
        assert_equal false,  Time.utc(2005, 2, 10, 20, 30, 45).future?
        assert_equal true,  Time.utc(2005, 2, 10, 20, 30, 46).future?
      end
    end
  end

  def test_future_with_time_current_as_time_with_zone
    with_env_tz "US/Eastern" do
      twz = Time.utc(2005, 2, 10, 15, 30, 45).in_time_zone("Central Time (US & Canada)")
      Time.stub(:current, twz) do
        assert_equal false,  Time.local(2005, 2, 10, 10, 30, 44).future?
        assert_equal false,  Time.local(2005, 2, 10, 10, 30, 45).future?
        assert_equal true,  Time.local(2005, 2, 10, 10, 30, 46).future?
        assert_equal false,  Time.utc(2005, 2, 10, 15, 30, 44).future?
        assert_equal false,  Time.utc(2005, 2, 10, 15, 30, 45).future?
        assert_equal true,  Time.utc(2005, 2, 10, 15, 30, 46).future?
      end
    end
  end

  def test_acts_like_time
    assert_predicate Time.new, :acts_like_time?
  end

  def test_formatted_offset_with_utc
    assert_equal "+00:00", Time.utc(2000).formatted_offset
    assert_equal "+0000", Time.utc(2000).formatted_offset(false)
    assert_equal "UTC", Time.utc(2000).formatted_offset(true, "UTC")
  end

  def test_formatted_offset_with_local
    with_env_tz "US/Eastern" do
      assert_equal "-05:00", Time.local(2000).formatted_offset
      assert_equal "-0500", Time.local(2000).formatted_offset(false)
      assert_equal "-04:00", Time.local(2000, 7).formatted_offset
      assert_equal "-0400", Time.local(2000, 7).formatted_offset(false)
    end
  end

  def test_compare_with_time
    assert_equal 1, Time.utc(2000) <=> Time.utc(1999, 12, 31, 23, 59, 59, 999)
    assert_equal 0, Time.utc(2000) <=> Time.utc(2000, 1, 1, 0, 0, 0)
    assert_equal(-1, Time.utc(2000) <=> Time.utc(2000, 1, 1, 0, 0, 0, 001))
  end

  def test_compare_with_datetime
    assert_equal 1, Time.utc(2000) <=> DateTime.civil(1999, 12, 31, 23, 59, 59)
    assert_equal 0, Time.utc(2000) <=> DateTime.civil(2000, 1, 1, 0, 0, 0)
    assert_equal(-1, Time.utc(2000) <=> DateTime.civil(2000, 1, 1, 0, 0, 1))
  end

  def test_compare_with_time_with_zone
    assert_equal 1, Time.utc(2000) <=> ActiveSupport::TimeWithZone.new(Time.utc(1999, 12, 31, 23, 59, 59), ActiveSupport::TimeZone["UTC"])
    assert_equal 0, Time.utc(2000) <=> ActiveSupport::TimeWithZone.new(Time.utc(2000, 1, 1, 0, 0, 0), ActiveSupport::TimeZone["UTC"])
    assert_equal(-1, Time.utc(2000) <=> ActiveSupport::TimeWithZone.new(Time.utc(2000, 1, 1, 0, 0, 1), ActiveSupport::TimeZone["UTC"]))
  end

  def test_compare_with_string
    assert_equal 1, Time.utc(2000) <=> Time.utc(1999, 12, 31, 23, 59, 59, 999).to_s
    assert_equal 0, Time.utc(2000) <=> Time.utc(2000, 1, 1, 0, 0, 0).to_s
    assert_equal(-1, Time.utc(2000) <=> Time.utc(2000, 1, 1, 0, 0, 1, 0).to_s)
    assert_nil Time.utc(2000) <=> "Invalid as Time"
  end

  def test_at_with_datetime
    assert_equal Time.utc(2000, 1, 1, 0, 0, 0), Time.at(DateTime.civil(2000, 1, 1, 0, 0, 0))

    # Only test this if the underlying Time.at raises a TypeError
    begin
      Time.at_without_coercion(Time.now, 0)
    rescue TypeError
      assert_raise(TypeError) { assert_equal(Time.utc(2000, 1, 1, 0, 0, 0), Time.at(DateTime.civil(2000, 1, 1, 0, 0, 0), 0)) }
    end
  end

  def test_at_with_datetime_returns_local_time
    with_env_tz "US/Eastern" do
      dt = DateTime.civil(2000, 1, 1, 0, 0, 0, "+0")
      assert_equal Time.local(1999, 12, 31, 19, 0, 0), Time.at(dt)
      assert_equal "EST", Time.at(dt).zone
      assert_equal(-18000, Time.at(dt).utc_offset)

      # Daylight savings
      dt = DateTime.civil(2000, 7, 1, 1, 0, 0, "+1")
      assert_equal Time.local(2000, 6, 30, 20, 0, 0), Time.at(dt)
      assert_equal "EDT", Time.at(dt).zone
      assert_equal(-14400, Time.at(dt).utc_offset)
    end
  end

  def test_at_with_time_with_zone
    assert_equal Time.utc(2000, 1, 1, 0, 0, 0), Time.at(ActiveSupport::TimeWithZone.new(Time.utc(2000, 1, 1, 0, 0, 0), ActiveSupport::TimeZone["UTC"]))
    assert_equal Time.utc(2000, 1, 1, 0, 0, 0), Time.at(ActiveSupport::TimeWithZone.new(Time.utc(2000, 1, 1, 0, 0, 0), ActiveSupport::TimeZone["UTC"]), 0)
  end

  def test_at_with_time_with_zone_precision
    time_with_nsec = Time.at(500000000, 123456789, :nsec)
    time_with_zone = ActiveSupport::TimeWithZone.new(time_with_nsec, ActiveSupport::TimeZone["UTC"])
    assert_equal time_with_zone, Time.at(time_with_zone)
    assert_equal time_with_zone.to_r, Time.at(time_with_zone).to_r
    assert_equal time_with_zone.to_f, Time.at(time_with_zone).to_f
    assert_equal time_with_zone.nsec, Time.at(time_with_zone).nsec
  end

  def test_at_with_time_with_zone_returns_local_time
    with_env_tz "US/Eastern" do
      twz = ActiveSupport::TimeWithZone.new(Time.utc(2000, 1, 1, 0, 0, 0), ActiveSupport::TimeZone["London"])
      assert_equal Time.local(1999, 12, 31, 19, 0, 0), Time.at(twz)
      assert_equal "EST", Time.at(twz).zone
      assert_equal(-18000, Time.at(twz).utc_offset)

      # Daylight savings
      twz = ActiveSupport::TimeWithZone.new(Time.utc(2000, 7, 1, 0, 0, 0), ActiveSupport::TimeZone["London"])
      assert_equal Time.local(2000, 6, 30, 20, 0, 0), Time.at(twz)
      assert_equal "EDT", Time.at(twz).zone
      assert_equal(-14400, Time.at(twz).utc_offset)
    end
  end

  def test_at_with_time_microsecond_precision
    assert_equal Time.at(Time.utc(2000, 1, 1, 0, 0, 0, 111)).to_f, Time.utc(2000, 1, 1, 0, 0, 0, 111).to_f
  end

  def test_at_with_utc_time
    with_env_tz "US/Eastern" do
      assert_equal Time.utc(2000), Time.at(Time.utc(2000))
      assert_equal "UTC", Time.at(Time.utc(2000)).zone
      assert_equal(0, Time.at(Time.utc(2000)).utc_offset)
    end
  end

  def test_at_with_local_time
    with_env_tz "US/Eastern" do
      assert_equal Time.local(2000), Time.at(Time.local(2000))
      assert_equal "EST", Time.at(Time.local(2000)).zone
      assert_equal(-18000, Time.at(Time.local(2000)).utc_offset)

      assert_equal Time.local(2000, 7, 1), Time.at(Time.local(2000, 7, 1))
      assert_equal "EDT", Time.at(Time.local(2000, 7, 1)).zone
      assert_equal(-14400, Time.at(Time.local(2000, 7, 1)).utc_offset)
    end
  end

  def test_eql?
    assert_equal true, Time.utc(2000).eql?(ActiveSupport::TimeWithZone.new(Time.utc(2000), ActiveSupport::TimeZone["UTC"]))
    assert_equal true, Time.utc(2000).eql?(ActiveSupport::TimeWithZone.new(Time.utc(2000), ActiveSupport::TimeZone["Hawaii"]))
    assert_equal false, Time.utc(2000, 1, 1, 0, 0, 1).eql?(ActiveSupport::TimeWithZone.new(Time.utc(2000), ActiveSupport::TimeZone["UTC"]))
  end

  def test_minus_with_time_with_zone
    assert_equal 86_400.0, Time.utc(2000, 1, 2) - ActiveSupport::TimeWithZone.new(Time.utc(2000, 1, 1), ActiveSupport::TimeZone["UTC"])
  end

  def test_minus_with_datetime
    assert_equal 86_400.0, Time.utc(2000, 1, 2) - DateTime.civil(2000, 1, 1)
  end

  def test_time_created_with_local_constructor_cannot_represent_times_during_hour_skipped_by_dst
    with_env_tz "US/Eastern" do
      # On Apr 2 2006 at 2:00AM in US, clocks were moved forward to 3:00AM.
      # Therefore, 2AM EST doesn't exist for this date; Time.local fails over to 3:00AM EDT
      assert_equal Time.local(2006, 4, 2, 3), Time.local(2006, 4, 2, 2)
      assert_predicate Time.local(2006, 4, 2, 2), :dst?
    end
  end

  def test_case_equality
    assert Time === Time.utc(2000)
    assert Time === ActiveSupport::TimeWithZone.new(Time.utc(2000), ActiveSupport::TimeZone["UTC"])
    assert Time === Class.new(Time).utc(2000)
    assert_equal false, Time === DateTime.civil(2000)
    assert_equal false, Class.new(Time) === Time.utc(2000)
    assert_equal false, Class.new(Time) === ActiveSupport::TimeWithZone.new(Time.utc(2000), ActiveSupport::TimeZone["UTC"])
  end

  def test_all_day
    assert_equal Time.local(2011, 6, 7, 0, 0, 0)..Time.local(2011, 6, 7, 23, 59, 59, Rational(999999999, 1000)), Time.local(2011, 6, 7, 10, 10, 10).all_day
  end

  def test_all_day_with_timezone
    beginning_of_day = ActiveSupport::TimeWithZone.new(nil, ActiveSupport::TimeZone["Hawaii"], Time.local(2011, 6, 7, 0, 0, 0))
    end_of_day = ActiveSupport::TimeWithZone.new(nil, ActiveSupport::TimeZone["Hawaii"], Time.local(2011, 6, 7, 23, 59, 59, Rational(999999999, 1000)))

    assert_equal beginning_of_day, ActiveSupport::TimeWithZone.new(Time.local(2011, 6, 7, 10, 10, 10), ActiveSupport::TimeZone["Hawaii"]).all_day.begin
    assert_equal end_of_day, ActiveSupport::TimeWithZone.new(Time.local(2011, 6, 7, 10, 10, 10), ActiveSupport::TimeZone["Hawaii"]).all_day.end
  end

  def test_all_week
    assert_equal Time.local(2011, 6, 6, 0, 0, 0)..Time.local(2011, 6, 12, 23, 59, 59, Rational(999999999, 1000)), Time.local(2011, 6, 7, 10, 10, 10).all_week
    assert_equal Time.local(2011, 6, 5, 0, 0, 0)..Time.local(2011, 6, 11, 23, 59, 59, Rational(999999999, 1000)), Time.local(2011, 6, 7, 10, 10, 10).all_week(:sunday)
  end

  def test_all_month
    assert_equal Time.local(2011, 6, 1, 0, 0, 0)..Time.local(2011, 6, 30, 23, 59, 59, Rational(999999999, 1000)), Time.local(2011, 6, 7, 10, 10, 10).all_month
  end

  def test_all_quarter
    assert_equal Time.local(2011, 4, 1, 0, 0, 0)..Time.local(2011, 6, 30, 23, 59, 59, Rational(999999999, 1000)), Time.local(2011, 6, 7, 10, 10, 10).all_quarter
  end

  def test_all_year
    assert_equal Time.local(2011, 1, 1, 0, 0, 0)..Time.local(2011, 12, 31, 23, 59, 59, Rational(999999999, 1000)), Time.local(2011, 6, 7, 10, 10, 10).all_year
  end

  def test_rfc3339_parse
    time = Time.rfc3339("1999-12-31T19:00:00.125-05:00")

    assert_equal 1999, time.year
    assert_equal 12, time.month
    assert_equal 31, time.day
    assert_equal 19, time.hour
    assert_equal 0, time.min
    assert_equal 0, time.sec
    assert_equal 125000, time.usec
    assert_equal(-18000, time.utc_offset)

    exception = assert_raises(ArgumentError) do
      Time.rfc3339("1999-12-31")
    end

    assert_equal "invalid date", exception.message

    exception = assert_raises(ArgumentError) do
      Time.rfc3339("1999-12-31T19:00:00")
    end

    assert_equal "invalid date", exception.message

    exception = assert_raises(ArgumentError) do
      Time.rfc3339("foobar")
    end

    assert_equal "invalid date", exception.message
  end

  def test_prev_day
    assert_equal date_time_init(2005, 2, 24, 10, 10, 10), date_time_init(2005, 2, 22, 10, 10, 10).prev_day(-2)
    assert_equal date_time_init(2005, 2, 23, 10, 10, 10), date_time_init(2005, 2, 22, 10, 10, 10).prev_day(-1)
    assert_equal date_time_init(2005, 2, 22, 10, 10, 10), date_time_init(2005, 2, 22, 10, 10, 10).prev_day(0)
    assert_equal date_time_init(2005, 2, 21, 10, 10, 10), date_time_init(2005, 2, 22, 10, 10, 10).prev_day(1)
    assert_equal date_time_init(2005, 2, 20, 10, 10, 10), date_time_init(2005, 2, 22, 10, 10, 10).prev_day(2)
    assert_equal date_time_init(2005, 2, 21, 10, 10, 10), date_time_init(2005, 2, 22, 10, 10, 10).prev_day
    assert_equal date_time_init(2005, 2, 28, 10, 10, 10), date_time_init(2005, 3, 2, 10, 10, 10).prev_day.prev_day
  end

  def test_next_day
    assert_equal date_time_init(2005, 2, 20, 10, 10, 10), date_time_init(2005, 2, 22, 10, 10, 10).next_day(-2)
    assert_equal date_time_init(2005, 2, 21, 10, 10, 10), date_time_init(2005, 2, 22, 10, 10, 10).next_day(-1)
    assert_equal date_time_init(2005, 2, 22, 10, 10, 10), date_time_init(2005, 2, 22, 10, 10, 10).next_day(0)
    assert_equal date_time_init(2005, 2, 23, 10, 10, 10), date_time_init(2005, 2, 22, 10, 10, 10).next_day(1)
    assert_equal date_time_init(2005, 2, 24, 10, 10, 10), date_time_init(2005, 2, 22, 10, 10, 10).next_day(2)
    assert_equal date_time_init(2005, 2, 23, 10, 10, 10), date_time_init(2005, 2, 22, 10, 10, 10).next_day
    assert_equal date_time_init(2005, 3, 2, 10, 10, 10),  date_time_init(2005, 2, 28, 10, 10, 10).next_day.next_day
  end

  def test_prev_month
    assert_equal date_time_init(2005, 4, 22, 10, 10, 10), date_time_init(2005, 2, 22, 10, 10, 10).prev_month(-2)
    assert_equal date_time_init(2005, 3, 22, 10, 10, 10), date_time_init(2005, 2, 22, 10, 10, 10).prev_month(-1)
    assert_equal date_time_init(2005, 2, 22, 10, 10, 10), date_time_init(2005, 2, 22, 10, 10, 10).prev_month(0)
    assert_equal date_time_init(2005, 1, 22, 10, 10, 10), date_time_init(2005, 2, 22, 10, 10, 10).prev_month(1)
    assert_equal date_time_init(2004, 12, 22, 10, 10, 10), date_time_init(2005, 2, 22, 10, 10, 10).prev_month(2)
    assert_equal date_time_init(2005, 1, 22, 10, 10, 10), date_time_init(2005, 2, 22, 10, 10, 10).prev_month
    assert_equal date_time_init(2004, 12, 22, 10, 10, 10), date_time_init(2005, 2, 22, 10, 10, 10).prev_month.prev_month
  end

  def test_next_month
    assert_equal date_time_init(2004, 12, 22, 10, 10, 10), date_time_init(2005, 2, 22, 10, 10, 10).next_month(-2)
    assert_equal date_time_init(2005, 1, 22, 10, 10, 10), date_time_init(2005, 2, 22, 10, 10, 10).next_month(-1)
    assert_equal date_time_init(2005, 2, 22, 10, 10, 10), date_time_init(2005, 2, 22, 10, 10, 10).next_month(0)
    assert_equal date_time_init(2005, 3, 22, 10, 10, 10), date_time_init(2005, 2, 22, 10, 10, 10).next_month(1)
    assert_equal date_time_init(2005, 4, 22, 10, 10, 10), date_time_init(2005, 2, 22, 10, 10, 10).next_month(2)
    assert_equal date_time_init(2005, 3, 22, 10, 10, 10), date_time_init(2005, 2, 22, 10, 10, 10).next_month
    assert_equal date_time_init(2005, 4, 22, 10, 10, 10), date_time_init(2005, 2, 22, 10, 10, 10).next_month.next_month
  end

  def test_prev_year
    assert_equal date_time_init(2007, 6, 5, 10, 10, 10),  date_time_init(2005, 6, 5, 10, 10, 10).prev_year(-2)
    assert_equal date_time_init(2006, 6, 5, 10, 10, 10),  date_time_init(2005, 6, 5, 10, 10, 10).prev_year(-1)
    assert_equal date_time_init(2005, 6, 5, 10, 10, 10),  date_time_init(2005, 6, 5, 10, 10, 10).prev_year(0)
    assert_equal date_time_init(2004, 6, 5, 10, 10, 10),  date_time_init(2005, 6, 5, 10, 10, 10).prev_year(1)
    assert_equal date_time_init(2003, 6, 5, 10, 10, 10),  date_time_init(2005, 6, 5, 10, 10, 10).prev_year(2)
    assert_equal date_time_init(2004, 6, 5, 10, 10, 10),  date_time_init(2005, 6, 5, 10, 10, 10).prev_year
    assert_equal date_time_init(2003, 6, 5, 10, 10, 10),  date_time_init(2005, 6, 5, 10, 10, 10).prev_year.prev_year
  end

  def test_next_year
    assert_equal date_time_init(2003, 6, 5, 10, 10, 10), date_time_init(2005, 6, 5, 10, 10, 10).next_year(-2)
    assert_equal date_time_init(2004, 6, 5, 10, 10, 10), date_time_init(2005, 6, 5, 10, 10, 10).next_year(-1)
    assert_equal date_time_init(2005, 6, 5, 10, 10, 10), date_time_init(2005, 6, 5, 10, 10, 10).next_year(0)
    assert_equal date_time_init(2006, 6, 5, 10, 10, 10), date_time_init(2005, 6, 5, 10, 10, 10).next_year(1)
    assert_equal date_time_init(2007, 6, 5, 10, 10, 10), date_time_init(2005, 6, 5, 10, 10, 10).next_year(2)
    assert_equal date_time_init(2006, 6, 5, 10, 10, 10), date_time_init(2005, 6, 5, 10, 10, 10).next_year
    assert_equal date_time_init(2007, 6, 5, 10, 10, 10), date_time_init(2005, 6, 5, 10, 10, 10).next_year.next_year
  end
end

class TimeExtMarshalingTest < ActiveSupport::TestCase
  def test_marshalling_with_utc_instance
    t = Time.utc(2000)
    unmarshalled = Marshal.load(Marshal.dump(t))
    assert_equal "UTC", unmarshalled.zone
    assert_equal t, unmarshalled
  end

  def test_marshalling_with_local_instance
    t = Time.local(2000)
    unmarshalled = Marshal.load(Marshal.dump(t))
    assert_equal t.zone, unmarshalled.zone
    assert_equal t, unmarshalled
  end

  def test_marshalling_with_frozen_utc_instance
    t = Time.utc(2000).freeze
    unmarshalled = Marshal.load(Marshal.dump(t))
    assert_equal "UTC", unmarshalled.zone
    assert_equal t, unmarshalled
  end

  def test_marshalling_with_frozen_local_instance
    t = Time.local(2000).freeze
    unmarshalled = Marshal.load(Marshal.dump(t))
    assert_equal t.zone, unmarshalled.zone
    assert_equal t, unmarshalled
  end

  def test_marshalling_preserves_fractional_seconds
    t = Time.parse("00:00:00.500")
    unmarshalled = Marshal.load(Marshal.dump(t))
    assert_equal t.to_f, unmarshalled.to_f
    assert_equal t, unmarshalled
  end

  def test_last_quarter_on_31st
    assert_equal Time.local(2004, 2, 29), Time.local(2004, 5, 31).last_quarter
  end
end
