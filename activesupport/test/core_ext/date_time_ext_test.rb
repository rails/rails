# frozen_string_literal: true

require_relative "../abstract_unit"
require "active_support/time"
require_relative "../core_ext/date_and_time_behavior"
require_relative "../time_zone_test_helpers"

class DateTimeExtCalculationsTest < ActiveSupport::TestCase
  def date_time_init(year, month, day, hour, minute, second, usec = 0)
    DateTime.civil(year, month, day, hour, minute, second + (usec / 1000000))
  end

  include DateAndTimeBehavior
  include TimeZoneTestHelpers

  def test_to_fs
    datetime = DateTime.new(2005, 2, 21, 14, 30, 0, 0)
    assert_equal "2005-02-21 14:30:00",                 datetime.to_fs(:db)
    assert_equal "2005-02-21 14:30:00.000000000 +0000", datetime.to_fs(:inspect)
    assert_equal "14:30",                               datetime.to_fs(:time)
    assert_equal "21 Feb 14:30",                        datetime.to_fs(:short)
    assert_equal "February 21, 2005 14:30",             datetime.to_fs(:long)
    assert_equal "Mon, 21 Feb 2005 14:30:00 +0000",     datetime.to_fs(:rfc822)
    assert_equal "Mon, 21 Feb 2005 14:30:00 +0000",     datetime.to_fs(:rfc2822)
    assert_equal "February 21st, 2005 14:30",           datetime.to_fs(:long_ordinal)
    assert_match(/^2005-02-21T14:30:00(Z|\+00:00)$/,    datetime.to_fs)
    assert_match(/^2005-02-21T14:30:00(Z|\+00:00)$/,    datetime.to_fs(:not_existent))

    with_env_tz "US/Central" do
      assert_equal "2009-02-05T14:30:05-06:00", DateTime.civil(2009, 2, 5, 14, 30, 5, Rational(-21600, 86400)).to_fs(:iso8601)
      assert_equal "2008-06-09T04:05:01-05:00", DateTime.civil(2008, 6, 9, 4, 5, 1, Rational(-18000, 86400)).to_fs(:iso8601)
      assert_equal "2009-02-05T14:30:05+00:00", DateTime.civil(2009, 2, 5, 14, 30, 5).to_fs(:iso8601)
    end

    assert_equal "2005-02-21 14:30:00",                 datetime.to_formatted_s(:db)
  end

  def test_readable_inspect
    datetime = DateTime.new(2005, 2, 21, 14, 30, 0)
    assert_equal "Mon, 21 Feb 2005 14:30:00 +0000", datetime.readable_inspect
    assert_equal datetime.readable_inspect, datetime.inspect
  end

  def test_to_fs_with_custom_date_format
    Time::DATE_FORMATS[:custom] = "%Y%m%d%H%M%S"
    assert_equal "20050221143000", DateTime.new(2005, 2, 21, 14, 30, 0).to_fs(:custom)
  ensure
    Time::DATE_FORMATS.delete(:custom)
  end

  def test_localtime
    with_env_tz "US/Eastern" do
      assert_instance_of Time, DateTime.new(2016, 3, 11, 15, 11, 12, 0).localtime
      assert_equal Time.local(2016, 3, 11, 10, 11, 12), DateTime.new(2016, 3, 11, 15, 11, 12, 0).localtime
      assert_equal Time.local(2016, 3, 21, 11, 11, 12), DateTime.new(2016, 3, 21, 15, 11, 12, 0).localtime
      assert_equal Time.local(2016, 4, 1, 11, 11, 12), DateTime.new(2016, 4, 1, 16, 11, 12, Rational(1, 24)).localtime
    end
  end

  def test_getlocal
    with_env_tz "US/Eastern" do
      assert_instance_of Time, DateTime.new(2016, 3, 11, 15, 11, 12, 0).getlocal
      assert_equal Time.local(2016, 3, 11, 10, 11, 12), DateTime.new(2016, 3, 11, 15, 11, 12, 0).getlocal
      assert_equal Time.local(2016, 3, 21, 11, 11, 12), DateTime.new(2016, 3, 21, 15, 11, 12, 0).getlocal
      assert_equal Time.local(2016, 4, 1, 11, 11, 12), DateTime.new(2016, 4, 1, 16, 11, 12, Rational(1, 24)).getlocal
    end
  end

  def test_to_date
    assert_equal Date.new(2005, 2, 21), DateTime.new(2005, 2, 21, 14, 30, 0).to_date
  end

  def test_to_datetime
    assert_equal DateTime.new(2005, 2, 21, 14, 30, 0), DateTime.new(2005, 2, 21, 14, 30, 0).to_datetime
  end

  def test_to_time
    with_env_tz "US/Eastern" do
      assert_instance_of Time, DateTime.new(2005, 2, 21, 10, 11, 12, 0).to_time

      assert_equal Time.local(2005, 2, 21, 5, 11, 12).getlocal(0), DateTime.new(2005, 2, 21, 10, 11, 12, 0).to_time
      assert_equal Time.local(2005, 2, 21, 5, 11, 12).getlocal(0).utc_offset, DateTime.new(2005, 2, 21, 10, 11, 12, 0).to_time.utc_offset
    end
  end

  def test_to_time_preserves_fractional_seconds
    assert_equal Time.utc(2005, 2, 21, 10, 11, 12, 256), DateTime.new(2005, 2, 21, 10, 11, 12 + Rational(256, 1000000), 0).to_time
  end

  def test_civil_from_format
    assert_equal Time.local(2010, 5, 4, 0, 0, 0), DateTime.civil_from_format(:local, 2010, 5, 4)
    assert_equal Time.utc(2010, 5, 4, 0, 0, 0), DateTime.civil_from_format(:utc, 2010, 5, 4)
  end

  def test_seconds_since_midnight
    assert_equal 1, DateTime.civil(2005, 1, 1, 0, 0, 1).seconds_since_midnight
    assert_equal 60, DateTime.civil(2005, 1, 1, 0, 1, 0).seconds_since_midnight
    assert_equal 3660, DateTime.civil(2005, 1, 1, 1, 1, 0).seconds_since_midnight
    assert_equal 86399, DateTime.civil(2005, 1, 1, 23, 59, 59).seconds_since_midnight
  end

  def test_seconds_until_end_of_day
    assert_equal 0, DateTime.civil(2005, 1, 1, 23, 59, 59).seconds_until_end_of_day
    assert_equal 1, DateTime.civil(2005, 1, 1, 23, 59, 58).seconds_until_end_of_day
    assert_equal 60, DateTime.civil(2005, 1, 1, 23, 58, 59).seconds_until_end_of_day
    assert_equal 3660, DateTime.civil(2005, 1, 1, 22, 58, 59).seconds_until_end_of_day
    assert_equal 86399, DateTime.civil(2005, 1, 1, 0, 0, 0).seconds_until_end_of_day
  end

  def test_beginning_of_day
    assert_equal DateTime.civil(2005, 2, 4, 0, 0, 0), DateTime.civil(2005, 2, 4, 10, 10, 10).beginning_of_day
  end

  def test_middle_of_day
    assert_equal DateTime.civil(2005, 2, 4, 12, 0, 0), DateTime.civil(2005, 2, 4, 10, 10, 10).middle_of_day
  end

  def test_end_of_day
    assert_equal DateTime.civil(2005, 2, 4, 23, 59, Rational(59999999999, 1000000000)), DateTime.civil(2005, 2, 4, 10, 10, 10).end_of_day
  end

  def test_beginning_of_hour
    assert_equal DateTime.civil(2005, 2, 4, 19, 0, 0), DateTime.civil(2005, 2, 4, 19, 30, 10).beginning_of_hour
  end

  def test_end_of_hour
    assert_equal DateTime.civil(2005, 2, 4, 19, 59, Rational(59999999999, 1000000000)), DateTime.civil(2005, 2, 4, 19, 30, 10).end_of_hour
  end

  def test_beginning_of_minute
    assert_equal DateTime.civil(2005, 2, 4, 19, 30, 0), DateTime.civil(2005, 2, 4, 19, 30, 10).beginning_of_minute
  end

  def test_end_of_minute
    assert_equal DateTime.civil(2005, 2, 4, 19, 30, Rational(59999999999, 1000000000)), DateTime.civil(2005, 2, 4, 19, 30, 10).end_of_minute
  end

  def test_end_of_month
    assert_equal DateTime.civil(2005, 3, 31, 23, 59, Rational(59999999999, 1000000000)), DateTime.civil(2005, 3, 20, 10, 10, 10).end_of_month
    assert_equal DateTime.civil(2005, 2, 28, 23, 59, Rational(59999999999, 1000000000)), DateTime.civil(2005, 2, 20, 10, 10, 10).end_of_month
    assert_equal DateTime.civil(2005, 4, 30, 23, 59, Rational(59999999999, 1000000000)), DateTime.civil(2005, 4, 20, 10, 10, 10).end_of_month
  end

  def test_ago
    assert_equal DateTime.civil(2005, 2, 22, 10, 10, 9),  DateTime.civil(2005, 2, 22, 10, 10, 10).ago(1)
    assert_equal DateTime.civil(2005, 2, 22, 9, 10, 10),  DateTime.civil(2005, 2, 22, 10, 10, 10).ago(3600)
    assert_equal DateTime.civil(2005, 2, 20, 10, 10, 10), DateTime.civil(2005, 2, 22, 10, 10, 10).ago(86400 * 2)
    assert_equal DateTime.civil(2005, 2, 20, 9, 9, 45),   DateTime.civil(2005, 2, 22, 10, 10, 10).ago(86400 * 2 + 3600 + 25)
  end

  def test_since
    assert_equal DateTime.civil(2005, 2, 22, 10, 10, 11), DateTime.civil(2005, 2, 22, 10, 10, 10).since(1)
    assert_equal DateTime.civil(2005, 2, 22, 11, 10, 10), DateTime.civil(2005, 2, 22, 10, 10, 10).since(3600)
    assert_equal DateTime.civil(2005, 2, 24, 10, 10, 10), DateTime.civil(2005, 2, 22, 10, 10, 10).since(86400 * 2)
    assert_equal DateTime.civil(2005, 2, 24, 11, 10, 35), DateTime.civil(2005, 2, 22, 10, 10, 10).since(86400 * 2 + 3600 + 25)
    assert_not_equal DateTime.civil(2005, 2, 22, 10, 10, 11), DateTime.civil(2005, 2, 22, 10, 10, 10).since(1.333)
    assert_not_equal DateTime.civil(2005, 2, 22, 10, 10, 12), DateTime.civil(2005, 2, 22, 10, 10, 10).since(1.667)
  end

  def test_change
    assert_equal DateTime.civil(2006, 2, 22, 15, 15, 10), DateTime.civil(2005, 2, 22, 15, 15, 10).change(year: 2006)
    assert_equal DateTime.civil(2005, 6, 22, 15, 15, 10), DateTime.civil(2005, 2, 22, 15, 15, 10).change(month: 6)
    assert_equal DateTime.civil(2012, 9, 22, 15, 15, 10), DateTime.civil(2005, 2, 22, 15, 15, 10).change(year: 2012, month: 9)
    assert_equal DateTime.civil(2005, 2, 22, 16),         DateTime.civil(2005, 2, 22, 15, 15, 10).change(hour: 16)
    assert_equal DateTime.civil(2005, 2, 22, 16, 45),     DateTime.civil(2005, 2, 22, 15, 15, 10).change(hour: 16, min: 45)
    assert_equal DateTime.civil(2005, 2, 22, 15, 45),     DateTime.civil(2005, 2, 22, 15, 15, 10).change(min: 45)

    # datetime with non-zero offset
    assert_equal DateTime.civil(2005, 2, 22, 15, 15, 10, Rational(-5, 24)), DateTime.civil(2005, 2, 22, 15, 15, 10, 0).change(offset: Rational(-5, 24))

    # datetime with fractions of a second
    assert_equal DateTime.civil(2005, 2, 1, 15, 15, 10.7), DateTime.civil(2005, 2, 22, 15, 15, 10.7).change(day: 1)
    assert_equal DateTime.civil(2005, 1, 2, 11, 22, Rational(33000008, 1000000)), DateTime.civil(2005, 1, 2, 11, 22, 33).change(usec: 8)
    assert_equal DateTime.civil(2005, 1, 2, 11, 22, Rational(33000008, 1000000)), DateTime.civil(2005, 1, 2, 11, 22, 33).change(nsec: 8000)
    assert_raise(ArgumentError) { DateTime.civil(2005, 1, 2, 11, 22, 0).change(usec: 1, nsec: 1) }
    assert_raise(ArgumentError) { DateTime.civil(2005, 1, 2, 11, 22, 0).change(usec: 1000000) }
    assert_raise(ArgumentError) { DateTime.civil(2005, 1, 2, 11, 22, 0).change(nsec: 1000000000) }
    assert_nothing_raised { DateTime.civil(2005, 1, 2, 11, 22, 0).change(usec: 999999) }
    assert_nothing_raised { DateTime.civil(2005, 1, 2, 11, 22, 0).change(nsec: 999999999) }
  end

  def test_advance
    assert_equal DateTime.civil(2006, 2, 28, 15, 15, 10),  DateTime.civil(2005, 2, 28, 15, 15, 10).advance(years: 1)
    assert_equal DateTime.civil(2005, 6, 28, 15, 15, 10),  DateTime.civil(2005, 2, 28, 15, 15, 10).advance(months: 4)
    assert_equal DateTime.civil(2005, 3, 21, 15, 15, 10),  DateTime.civil(2005, 2, 28, 15, 15, 10).advance(weeks: 3)
    assert_equal DateTime.civil(2005, 3, 5, 15, 15, 10),   DateTime.civil(2005, 2, 28, 15, 15, 10).advance(days: 5)
    assert_equal DateTime.civil(2012, 9, 28, 15, 15, 10),  DateTime.civil(2005, 2, 28, 15, 15, 10).advance(years: 7, months: 7)
    assert_equal DateTime.civil(2013, 10, 3, 15, 15, 10),  DateTime.civil(2005, 2, 28, 15, 15, 10).advance(years: 7, months: 19, days: 5)
    assert_equal DateTime.civil(2013, 10, 17, 15, 15, 10), DateTime.civil(2005, 2, 28, 15, 15, 10).advance(years: 7, months: 19, weeks: 2, days: 5)
    assert_equal DateTime.civil(2001, 12, 27, 15, 15, 10), DateTime.civil(2005, 2, 28, 15, 15, 10).advance(years: -3, months: -2, days: -1)
    assert_equal DateTime.civil(2005, 2, 28, 15, 15, 10),  DateTime.civil(2004, 2, 29, 15, 15, 10).advance(years: 1) # leap day plus one year
    assert_equal DateTime.civil(2005, 2, 28, 20, 15, 10),  DateTime.civil(2005, 2, 28, 15, 15, 10).advance(hours: 5)
    assert_equal DateTime.civil(2005, 2, 28, 15, 22, 10),  DateTime.civil(2005, 2, 28, 15, 15, 10).advance(minutes: 7)
    assert_equal DateTime.civil(2005, 2, 28, 15, 15, 19),  DateTime.civil(2005, 2, 28, 15, 15, 10).advance(seconds: 9)
    assert_equal DateTime.civil(2005, 2, 28, 20, 22, 19),  DateTime.civil(2005, 2, 28, 15, 15, 10).advance(hours: 5, minutes: 7, seconds: 9)
    assert_equal DateTime.civil(2005, 2, 28, 10, 8, 1),    DateTime.civil(2005, 2, 28, 15, 15, 10).advance(hours: -5, minutes: -7, seconds: -9)
    assert_equal DateTime.civil(2013, 10, 17, 20, 22, 19), DateTime.civil(2005, 2, 28, 15, 15, 10).advance(years: 7, months: 19, weeks: 2, days: 5, hours: 5, minutes: 7, seconds: 9)
  end

  def test_advance_partial_days
    assert_equal DateTime.civil(2012, 9, 29, 13, 15, 10),  DateTime.civil(2012, 9, 28, 1, 15, 10).advance(days: 1.5)
    assert_equal DateTime.civil(2012, 9, 28, 13, 15, 10),  DateTime.civil(2012, 9, 28, 1, 15, 10).advance(days: 0.5)
    assert_equal DateTime.civil(2012, 10, 29, 13, 15, 10), DateTime.civil(2012, 9, 28, 1, 15, 10).advance(days: 1.5, months: 1)
  end

  def test_advanced_processes_first_the_date_deltas_and_then_the_time_deltas
    # If the time deltas were processed first, the following datetimes would be advanced to 2010/04/01 instead.
    assert_equal DateTime.civil(2010, 3, 29), DateTime.civil(2010, 2, 28, 23, 59, 59).advance(months: 1, seconds: 1)
    assert_equal DateTime.civil(2010, 3, 29), DateTime.civil(2010, 2, 28, 23, 59).advance(months: 1, minutes: 1)
    assert_equal DateTime.civil(2010, 3, 29), DateTime.civil(2010, 2, 28, 23).advance(months: 1, hours: 1)
    assert_equal DateTime.civil(2010, 3, 29), DateTime.civil(2010, 2, 28, 22, 58, 59).advance(months: 1, hours: 1, minutes: 1, seconds: 1)
  end

  def test_last_week
    assert_equal DateTime.civil(2005, 2, 21), DateTime.civil(2005, 3, 1, 15, 15, 10).last_week
    assert_equal DateTime.civil(2005, 2, 22), DateTime.civil(2005, 3, 1, 15, 15, 10).last_week(:tuesday)
    assert_equal DateTime.civil(2005, 2, 25), DateTime.civil(2005, 3, 1, 15, 15, 10).last_week(:friday)
    assert_equal DateTime.civil(2006, 10, 30), DateTime.civil(2006, 11, 6, 0, 0, 0).last_week
    assert_equal DateTime.civil(2006, 11, 15), DateTime.civil(2006, 11, 23, 0, 0, 0).last_week(:wednesday)
  end

  def test_date_time_should_have_correct_last_week_for_leap_year
    assert_equal DateTime.civil(2016, 2, 29), DateTime.civil(2016, 3, 7).last_week
  end

  def test_last_quarter_on_31st
    assert_equal DateTime.civil(2004, 2, 29), DateTime.civil(2004, 5, 31).last_quarter
  end

  def test_xmlschema
    assert_match(/^1880-02-28T15:15:10\+00:?00$/, DateTime.civil(1880, 2, 28, 15, 15, 10).xmlschema)
    assert_match(/^1980-02-28T15:15:10\+00:?00$/, DateTime.civil(1980, 2, 28, 15, 15, 10).xmlschema)
    assert_match(/^2080-02-28T15:15:10\+00:?00$/, DateTime.civil(2080, 2, 28, 15, 15, 10).xmlschema)
    assert_match(/^1880-02-28T15:15:10-06:?00$/, DateTime.civil(1880, 2, 28, 15, 15, 10, -0.25).xmlschema)
    assert_match(/^1980-02-28T15:15:10-06:?00$/, DateTime.civil(1980, 2, 28, 15, 15, 10, -0.25).xmlschema)
    assert_match(/^2080-02-28T15:15:10-06:?00$/, DateTime.civil(2080, 2, 28, 15, 15, 10, -0.25).xmlschema)
  end

  def test_today_with_offset
    Date.stub(:current, Date.new(2000, 1, 1)) do
      assert_equal false, DateTime.civil(1999, 12, 31, 23, 59, 59, Rational(-18000, 86400)).today?
      assert_equal true,  DateTime.civil(2000, 1, 1, 0, 0, 0, Rational(-18000, 86400)).today?
      assert_equal true,  DateTime.civil(2000, 1, 1, 23, 59, 59, Rational(-18000, 86400)).today?
      assert_equal false, DateTime.civil(2000, 1, 2, 0, 0, 0, Rational(-18000, 86400)).today?
    end
  end

  def test_today_without_offset
    Date.stub(:current, Date.new(2000, 1, 1)) do
      assert_equal false, DateTime.civil(1999, 12, 31, 23, 59, 59).today?
      assert_equal true,  DateTime.civil(2000, 1, 1, 0).today?
      assert_equal true,  DateTime.civil(2000, 1, 1, 23, 59, 59).today?
      assert_equal false, DateTime.civil(2000, 1, 2, 0).today?
    end
  end

  def test_yesterday_with_offset
    Date.stub(:current, Date.new(2000, 1, 1)) do
      assert_equal true,  DateTime.civil(1999, 12, 31, 23, 59, 59, Rational(-18000, 86400)).yesterday?
      assert_equal false, DateTime.civil(2000, 1, 1, 0, 0, 0, Rational(-18000, 86400)).yesterday?
      assert_equal false, DateTime.civil(2000, 1, 1, 23, 59, 59, Rational(-18000, 86400)).yesterday?
      assert_equal true,  DateTime.civil(1999, 12, 31, 0, 0, 0, Rational(-18000, 86400)).yesterday?
    end
  end

  def test_yesterday_without_offset
    Date.stub(:current, Date.new(2000, 1, 1)) do
      assert_equal true,  DateTime.civil(1999, 12, 31, 23, 59, 59).yesterday?
      assert_equal false, DateTime.civil(2000, 1, 1, 0).yesterday?
      assert_equal false, DateTime.civil(2000, 1, 1, 23, 59, 59).yesterday?
      assert_equal false, DateTime.civil(2000, 1, 2, 0).yesterday?
    end
  end

  def test_prev_day_with_offset
    Date.stub(:current, Date.new(2000, 1, 1)) do
      assert_equal true,  DateTime.civil(1999, 12, 31, 23, 59, 59, Rational(-18000, 86400)).prev_day?
      assert_equal false, DateTime.civil(2000, 1, 1, 0, 0, 0, Rational(-18000, 86400)).prev_day?
      assert_equal false, DateTime.civil(2000, 1, 1, 23, 59, 59, Rational(-18000, 86400)).prev_day?
      assert_equal true,  DateTime.civil(1999, 12, 31, 0, 0, 0, Rational(-18000, 86400)).prev_day?
    end
  end

  def test_prev_day_without_offset
    Date.stub(:current, Date.new(2000, 1, 1)) do
      assert_equal true,  DateTime.civil(1999, 12, 31, 23, 59, 59).prev_day?
      assert_equal false, DateTime.civil(2000, 1, 1, 0).prev_day?
      assert_equal false, DateTime.civil(2000, 1, 1, 23, 59, 59).prev_day?
      assert_equal false, DateTime.civil(2000, 1, 2, 0).prev_day?
    end
  end

  def test_tomorrow_with_offset
    Date.stub(:current, Date.new(2000, 1, 1)) do
      assert_equal false, DateTime.civil(1999, 12, 31, 23, 59, 59, Rational(-18000, 86400)).tomorrow?
      assert_equal true,  DateTime.civil(2000, 1, 2, 0, 0, 0, Rational(-18000, 86400)).tomorrow?
      assert_equal false, DateTime.civil(2000, 1, 1, 23, 59, 59, Rational(-18000, 86400)).tomorrow?
      assert_equal true,  DateTime.civil(2000, 1, 2, 23, 59, 59, Rational(-18000, 86400)).tomorrow?
    end
  end

  def test_tomorrow_without_offset
    Date.stub(:current, Date.new(2000, 1, 1)) do
      assert_equal false, DateTime.civil(1999, 12, 31, 23, 59, 59).tomorrow?
      assert_equal true,  DateTime.civil(2000, 1, 2, 0).tomorrow?
      assert_equal false, DateTime.civil(2000, 1, 1, 23, 59, 59).tomorrow?
      assert_equal false, DateTime.civil(2000, 1, 3, 0).tomorrow?
    end
  end

  def test_next_day_with_offset
    Date.stub(:current, Date.new(2000, 1, 1)) do
      assert_equal false, DateTime.civil(1999, 12, 31, 23, 59, 59, Rational(-18000, 86400)).next_day?
      assert_equal true,  DateTime.civil(2000, 1, 2, 0, 0, 0, Rational(-18000, 86400)).next_day?
      assert_equal false, DateTime.civil(2000, 1, 1, 23, 59, 59, Rational(-18000, 86400)).next_day?
      assert_equal true,  DateTime.civil(2000, 1, 2, 23, 59, 59, Rational(-18000, 86400)).next_day?
    end
  end

  def test_next_day_without_offset
    Date.stub(:current, Date.new(2000, 1, 1)) do
      assert_equal false, DateTime.civil(1999, 12, 31, 23, 59, 59).next_day?
      assert_equal true,  DateTime.civil(2000, 1, 2, 0).next_day?
      assert_equal false, DateTime.civil(2000, 1, 1, 23, 59, 59).next_day?
      assert_equal false, DateTime.civil(2000, 1, 3, 0).next_day?
    end
  end

  def test_past_with_offset
    DateTime.stub(:current, DateTime.civil(2005, 2, 10, 15, 30, 45, Rational(-18000, 86400))) do
      assert_equal true,   DateTime.civil(2005, 2, 10, 15, 30, 44, Rational(-18000, 86400)).past?
      assert_equal false,  DateTime.civil(2005, 2, 10, 15, 30, 45, Rational(-18000, 86400)).past?
      assert_equal false,  DateTime.civil(2005, 2, 10, 15, 30, 46, Rational(-18000, 86400)).past?
    end
  end

  def test_past_without_offset
    DateTime.stub(:current, DateTime.civil(2005, 2, 10, 15, 30, 45, Rational(-18000, 86400))) do
      assert_equal true,  DateTime.civil(2005, 2, 10, 20, 30, 44).past?
      assert_equal false,  DateTime.civil(2005, 2, 10, 20, 30, 45).past?
      assert_equal false,  DateTime.civil(2005, 2, 10, 20, 30, 46).past?
    end
  end

  def test_future_with_offset
    DateTime.stub(:current, DateTime.civil(2005, 2, 10, 15, 30, 45, Rational(-18000, 86400))) do
      assert_equal false,  DateTime.civil(2005, 2, 10, 15, 30, 44, Rational(-18000, 86400)).future?
      assert_equal false,  DateTime.civil(2005, 2, 10, 15, 30, 45, Rational(-18000, 86400)).future?
      assert_equal true,  DateTime.civil(2005, 2, 10, 15, 30, 46, Rational(-18000, 86400)).future?
    end
  end

  def test_future_without_offset
    DateTime.stub(:current, DateTime.civil(2005, 2, 10, 15, 30, 45, Rational(-18000, 86400))) do
      assert_equal false,  DateTime.civil(2005, 2, 10, 20, 30, 44).future?
      assert_equal false,  DateTime.civil(2005, 2, 10, 20, 30, 45).future?
      assert_equal true,  DateTime.civil(2005, 2, 10, 20, 30, 46).future?
    end
  end

  def test_this_week
    Date.stub(:current, Date.new(2000, 1, 5)) do # Wed, 2000-01-05
      assert_equal false, Time.utc(2000, 1, 2, 23, 59, 59).this_week?
      assert_equal true,  Time.utc(2000, 1, 3, 0, 0, 0).this_week?
      assert_equal true,  Time.utc(2000, 1, 9, 23, 59, 59).this_week?
      assert_equal false, Time.utc(2000, 1, 10, 0, 0, 0).this_week?
    end
  end

  def test_this_month
    Date.stub(:current, Date.new(2000, 1, 15)) do
      assert_equal false, Time.utc(1999, 12, 31, 23, 59, 59).this_month?
      assert_equal true,  Time.utc(2000, 1, 1, 0, 0, 0).this_month?
      assert_equal true,  Time.utc(2000, 1, 31, 23, 59, 59).this_month?
      assert_equal false, Time.utc(2000, 2, 1, 0, 0, 0).this_month?
    end
  end

  def test_this_year
    Date.stub(:current, Date.new(2000, 6, 30)) do
      assert_equal false, Time.utc(1999, 12, 31, 23, 59, 59).this_year?
      assert_equal true,  Time.utc(2000, 1, 1, 0, 0, 0).this_year?
      assert_equal true,  Time.utc(2000, 12, 31, 23, 59, 59).this_year?
      assert_equal false, Time.utc(2001, 1, 1, 0, 0, 0).this_year?
    end
  end

  def test_current_returns_date_today_when_zone_is_not_set
    with_env_tz "US/Eastern" do
      Time.stub(:now, Time.local(1999, 12, 31, 23, 59, 59)) do
        assert_equal DateTime.new(1999, 12, 31, 23, 59, 59, Rational(-18000, 86400)), DateTime.current
      end
    end
  end

  def test_current_returns_time_zone_today_when_zone_is_set
    Time.zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    with_env_tz "US/Eastern" do
      Time.stub(:now, Time.local(1999, 12, 31, 23, 59, 59)) do
        assert_equal DateTime.new(1999, 12, 31, 23, 59, 59, Rational(-18000, 86400)), DateTime.current
      end
    end
  ensure
    Time.zone = nil
  end

  def test_current_without_time_zone
    assert_kind_of DateTime, DateTime.current
  end

  def test_current_with_time_zone
    with_env_tz "US/Eastern" do
      assert_kind_of DateTime, DateTime.current
    end
  end

  def test_acts_like_date
    assert_predicate DateTime.new, :acts_like_date?
  end

  def test_acts_like_time
    assert_predicate DateTime.new, :acts_like_time?
  end

  def test_blank?
    assert_not_predicate DateTime.new, :blank?
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
    assert_equal(-21600, DateTime.civil(2005, 2, 21, 10, 11, 12, -0.25).utc_offset)
    assert_equal(-18000, DateTime.civil(2005, 2, 21, 10, 11, 12, Rational(-5, 24)).utc_offset)
  end

  def test_utc
    assert_instance_of Time, DateTime.civil(2005, 2, 21, 10, 11, 12, Rational(-6, 24)).utc
    assert_equal DateTime.civil(2005, 2, 21, 16, 11, 12, 0), DateTime.civil(2005, 2, 21, 10, 11, 12, Rational(-6, 24)).utc
    assert_equal DateTime.civil(2005, 2, 21, 15, 11, 12, 0), DateTime.civil(2005, 2, 21, 10, 11, 12, Rational(-5, 24)).utc
    assert_equal DateTime.civil(2005, 2, 21, 10, 11, 12, 0), DateTime.civil(2005, 2, 21, 10, 11, 12, 0).utc
    assert_equal DateTime.civil(2005, 2, 21, 9, 11, 12, 0), DateTime.civil(2005, 2, 21, 10, 11, 12, Rational(1, 24)).utc
    assert_equal DateTime.civil(2005, 2, 21, 9, 11, 12, 0), DateTime.civil(2005, 2, 21, 10, 11, 12, Rational(1, 24)).getutc
  end

  def test_formatted_offset_with_utc
    assert_equal "+00:00", DateTime.civil(2000).formatted_offset
    assert_equal "+0000", DateTime.civil(2000).formatted_offset(false)
    assert_equal "UTC", DateTime.civil(2000).formatted_offset(true, "UTC")
  end

  def test_formatted_offset_with_local
    dt = DateTime.civil(2005, 2, 21, 10, 11, 12, Rational(-5, 24))
    assert_equal "-05:00", dt.formatted_offset
    assert_equal "-0500", dt.formatted_offset(false)
  end

  def test_compare_with_time
    assert_equal 1, DateTime.civil(2000) <=> Time.utc(1999, 12, 31, 23, 59, 59)
    assert_equal 0, DateTime.civil(2000) <=> Time.utc(2000, 1, 1, 0, 0, 0)
    assert_equal(-1, DateTime.civil(2000) <=> Time.utc(2000, 1, 1, 0, 0, 1))
  end

  def test_compare_with_datetime
    assert_equal 1, DateTime.civil(2000) <=> DateTime.civil(1999, 12, 31, 23, 59, 59)
    assert_equal 0, DateTime.civil(2000) <=> DateTime.civil(2000, 1, 1, 0, 0, 0)
    assert_equal(-1, DateTime.civil(2000) <=> DateTime.civil(2000, 1, 1, 0, 0, 1))
  end

  def test_compare_with_time_with_zone
    assert_equal 1, DateTime.civil(2000) <=> ActiveSupport::TimeWithZone.new(Time.utc(1999, 12, 31, 23, 59, 59), ActiveSupport::TimeZone["UTC"])
    assert_equal 0, DateTime.civil(2000) <=> ActiveSupport::TimeWithZone.new(Time.utc(2000, 1, 1, 0, 0, 0), ActiveSupport::TimeZone["UTC"])
    assert_equal(-1, DateTime.civil(2000) <=> ActiveSupport::TimeWithZone.new(Time.utc(2000, 1, 1, 0, 0, 1), ActiveSupport::TimeZone["UTC"]))
  end

  def test_compare_with_string
    assert_equal 1, DateTime.civil(2000) <=> Time.utc(1999, 12, 31, 23, 59, 59).to_s
    assert_equal 0, DateTime.civil(2000) <=> Time.utc(2000, 1, 1, 0, 0, 0).to_s
    assert_equal(-1, DateTime.civil(2000) <=> Time.utc(2000, 1, 1, 0, 0, 1).to_s)
    assert_nil DateTime.civil(2000) <=> "Invalid as Time"
  end

  def test_compare_with_integer
    assert_equal 1, DateTime.civil(1970, 1, 1, 12, 0, 0) <=> 2440587
    assert_equal 0, DateTime.civil(1970, 1, 1, 12, 0, 0) <=> 2440588
    assert_equal(-1, DateTime.civil(1970, 1, 1, 12, 0, 0) <=> 2440589)
  end

  def test_compare_with_float
    assert_equal 1, DateTime.civil(1970) <=> 2440586.5
    assert_equal 0, DateTime.civil(1970) <=> 2440587.5
    assert_equal(-1, DateTime.civil(1970) <=> 2440588.5)
  end

  def test_compare_with_rational
    assert_equal 1, DateTime.civil(1970) <=> Rational(4881173, 2)
    assert_equal 0, DateTime.civil(1970) <=> Rational(4881175, 2)
    assert_equal(-1, DateTime.civil(1970) <=> Rational(4881177, 2))
  end

  def test_to_f
    assert_equal 946684800.0, DateTime.civil(2000).to_f
    assert_equal 946684800.0, DateTime.civil(1999, 12, 31, 19, 0, 0, Rational(-5, 24)).to_f
    assert_equal 946684800.5, DateTime.civil(1999, 12, 31, 19, 0, 0.5, Rational(-5, 24)).to_f
  end

  def test_to_i
    assert_equal 946684800, DateTime.civil(2000).to_i
    assert_equal 946684800, DateTime.civil(1999, 12, 31, 19, 0, 0, Rational(-5, 24)).to_i
  end

  def test_usec
    assert_equal 0, DateTime.civil(2000).usec
    assert_equal 500000, DateTime.civil(2000, 1, 1, 0, 0, Rational(1, 2)).usec
  end

  def test_nsec
    assert_equal 0, DateTime.civil(2000).nsec
    assert_equal 500000000, DateTime.civil(2000, 1, 1, 0, 0, Rational(1, 2)).nsec
  end

  def test_subsec
    assert_equal 0, DateTime.civil(2000).subsec
    assert_equal Rational(1, 2), DateTime.civil(2000, 1, 1, 0, 0, Rational(1, 2)).subsec
  end
end
