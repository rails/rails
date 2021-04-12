# frozen_string_literal: true

require_relative "abstract_unit"
require "active_support/time"
require_relative "time_zone_test_helpers"
require "yaml"

class TimeZoneTest < ActiveSupport::TestCase
  include TimeZoneTestHelpers

  def test_utc_to_local
    zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]

    with_utc_to_local_returns_utc_offset_times false do
      assert_equal Time.utc(1999, 12, 31, 19), zone.utc_to_local(Time.utc(2000, 1)) # standard offset -0500
      assert_equal Time.utc(2000, 6, 30, 20), zone.utc_to_local(Time.utc(2000, 7)) # dst offset -0400
    end

    with_utc_to_local_returns_utc_offset_times true do
      assert_equal Time.new(1999, 12, 31, 19, 0, 0, -18000), zone.utc_to_local(Time.utc(2000, 1)) # standard offset -0500
      assert_equal Time.new(2000, 6, 30, 20, 0, 0, -14400), zone.utc_to_local(Time.utc(2000, 7)) # dst offset -0400
    end
  end

  def test_utc_to_local_with_fractional_seconds
    zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    usec = Rational(1, 1000000)

    with_utc_to_local_returns_utc_offset_times false do
      assert_equal Time.utc(1999, 12, 31, 19, 0, 0, 1), zone.utc_to_local(Time.utc(2000, 1, 1, 0, 0, 0, 1)) # standard offset -0500
      assert_equal Time.utc(2000, 6, 30, 20, 0, 0, 1), zone.utc_to_local(Time.utc(2000, 7, 1, 0, 0, 0, 1)) # dst offset -0400
    end

    with_utc_to_local_returns_utc_offset_times true do
      assert_equal Time.new(1999, 12, 31, 19, 0, usec, -18000), zone.utc_to_local(Time.utc(2000, 1, 1, 0, 0, 0, 1)) # standard offset -0500
      assert_equal Time.new(2000, 6, 30, 20, 0, usec, -14400), zone.utc_to_local(Time.utc(2000, 7, 1, 0, 0, 0, 1)) # dst offset -0400
    end
  end

  def test_local_to_utc
    zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    assert_equal Time.utc(2000, 1, 1, 5), zone.local_to_utc(Time.utc(2000, 1)) # standard offset -0500
    assert_equal Time.utc(2000, 7, 1, 4), zone.local_to_utc(Time.utc(2000, 7)) # dst offset -0400
  end

  def test_period_for_local
    zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    assert_kind_of TZInfo::TimezonePeriod, zone.period_for_local(Time.utc(2000))
  end

  ActiveSupport::TimeZone::MAPPING.each_key do |name|
    define_method("test_map_#{name.downcase.gsub(/[^a-z]/, '_')}_to_tzinfo") do
      zone = ActiveSupport::TimeZone[name]
      assert_respond_to zone.tzinfo, :period_for_local
    end
  end

  def test_period_for_local_with_ambiguous_time
    zone = ActiveSupport::TimeZone["Moscow"]
    period = zone.period_for_local(Time.utc(2015, 1, 1))
    assert_equal period, zone.period_for_local(Time.utc(2014, 10, 26, 1, 0, 0))
  end

  def test_from_integer_to_map
    assert_instance_of ActiveSupport::TimeZone, ActiveSupport::TimeZone[-28800] # PST
  end

  def test_from_duration_to_map
    assert_instance_of ActiveSupport::TimeZone, ActiveSupport::TimeZone[-480.minutes] # PST
  end

  ActiveSupport::TimeZone.all.each do |zone|
    name = zone.name.downcase.gsub(/[^a-z]/, "_")
    define_method("test_from_#{name}_to_map") do
      assert_instance_of ActiveSupport::TimeZone, ActiveSupport::TimeZone[zone.name]
    end

    define_method("test_utc_offset_for_#{name}") do
      period = zone.tzinfo.current_period
      assert_equal period.base_utc_offset, zone.utc_offset
    end
  end

  def test_now
    with_env_tz "US/Eastern" do
      zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"].dup
      def zone.time_now; Time.local(2000); end
      assert_instance_of ActiveSupport::TimeWithZone, zone.now
      assert_equal Time.utc(2000, 1, 1, 5), zone.now.utc
      assert_equal Time.utc(2000), zone.now.time
      assert_equal zone, zone.now.time_zone
    end
  end

  def test_now_enforces_spring_dst_rules
    with_env_tz "US/Eastern" do
      zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"].dup
      def zone.time_now
        Time.local(2006, 4, 2, 2) # 2AM springs forward to 3AM
      end

      assert_equal Time.utc(2006, 4, 2, 3), zone.now.time
      assert_equal true, zone.now.dst?
    end
  end

  def test_now_enforces_fall_dst_rules
    with_env_tz "US/Eastern" do
      zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"].dup
      def zone.time_now
        Time.at(1162098000) # equivalent to 1AM DST
      end
      assert_equal Time.utc(2006, 10, 29, 1), zone.now.time
      assert_equal true, zone.now.dst?
    end
  end

  def test_unknown_timezones_delegation_to_tzinfo
    zone = ActiveSupport::TimeZone["America/Montevideo"]
    assert_equal ActiveSupport::TimeZone, zone.class
    assert_equal zone.object_id, ActiveSupport::TimeZone["America/Montevideo"].object_id

    with_utc_to_local_returns_utc_offset_times false do
      assert_equal Time.utc(2010, 1, 31, 22), zone.utc_to_local(Time.utc(2010, 2)) # daylight saving offset -0200
      assert_equal Time.utc(2010, 3, 31, 21), zone.utc_to_local(Time.utc(2010, 4)) # standard offset -0300
    end
    with_utc_to_local_returns_utc_offset_times true do
      assert_equal Time.new(2010, 1, 31, 22, 0, 0, -7200), zone.utc_to_local(Time.utc(2010, 2)) # daylight saving offset -0200
      assert_equal Time.new(2010, 3, 31, 21, 0, 0, -10800), zone.utc_to_local(Time.utc(2010, 4)) # standard offset -0300
    end
  end

  def test_today
    travel_to(Time.utc(2000, 1, 1, 4, 59, 59)) # 1 sec before midnight Jan 1 EST
    assert_equal Date.new(1999, 12, 31), ActiveSupport::TimeZone["Eastern Time (US & Canada)"].today
    travel_to(Time.utc(2000, 1, 1, 5)) # midnight Jan 1 EST
    assert_equal Date.new(2000, 1, 1), ActiveSupport::TimeZone["Eastern Time (US & Canada)"].today
    travel_to(Time.utc(2000, 1, 2, 4, 59, 59)) # 1 sec before midnight Jan 2 EST
    assert_equal Date.new(2000, 1, 1), ActiveSupport::TimeZone["Eastern Time (US & Canada)"].today
    travel_to(Time.utc(2000, 1, 2, 5)) # midnight Jan 2 EST
    assert_equal Date.new(2000, 1, 2), ActiveSupport::TimeZone["Eastern Time (US & Canada)"].today
  end

  def test_tomorrow
    travel_to(Time.utc(2000, 1, 1, 4, 59, 59)) # 1 sec before midnight Jan 1 EST
    assert_equal Date.new(2000, 1, 1), ActiveSupport::TimeZone["Eastern Time (US & Canada)"].tomorrow
    travel_to(Time.utc(2000, 1, 1, 5)) # midnight Jan 1 EST
    assert_equal Date.new(2000, 1, 2), ActiveSupport::TimeZone["Eastern Time (US & Canada)"].tomorrow
    travel_to(Time.utc(2000, 1, 2, 4, 59, 59)) # 1 sec before midnight Jan 2 EST
    assert_equal Date.new(2000, 1, 2), ActiveSupport::TimeZone["Eastern Time (US & Canada)"].tomorrow
    travel_to(Time.utc(2000, 1, 2, 5)) # midnight Jan 2 EST
    assert_equal Date.new(2000, 1, 3), ActiveSupport::TimeZone["Eastern Time (US & Canada)"].tomorrow
  end

  def test_yesterday
    travel_to(Time.utc(2000, 1, 1, 4, 59, 59)) # 1 sec before midnight Jan 1 EST
    assert_equal Date.new(1999, 12, 30), ActiveSupport::TimeZone["Eastern Time (US & Canada)"].yesterday
    travel_to(Time.utc(2000, 1, 1, 5)) # midnight Jan 1 EST
    assert_equal Date.new(1999, 12, 31), ActiveSupport::TimeZone["Eastern Time (US & Canada)"].yesterday
    travel_to(Time.utc(2000, 1, 2, 4, 59, 59)) # 1 sec before midnight Jan 2 EST
    assert_equal Date.new(1999, 12, 31), ActiveSupport::TimeZone["Eastern Time (US & Canada)"].yesterday
    travel_to(Time.utc(2000, 1, 2, 5)) # midnight Jan 2 EST
    assert_equal Date.new(2000, 1, 1), ActiveSupport::TimeZone["Eastern Time (US & Canada)"].yesterday
  end

  def test_travel_to_a_date
    with_env_tz do
      Time.use_zone("Hawaii") do
        date = Date.new(2014, 2, 18)
        time = date.midnight

        travel_to date do
          assert_equal date, Date.current
          assert_equal time, Time.current
        end
      end
    end
  end

  def test_travel_to_travels_back_and_reraises_if_the_block_raises
    ts = Time.current - 1.second

    travel_to ts do
      raise
    end

    flunk # ensure travel_to re-raises
  rescue
    assert_not_equal ts, Time.current
  end

  def test_local
    time = ActiveSupport::TimeZone["Hawaii"].local(2007, 2, 5, 15, 30, 45)
    assert_equal Time.utc(2007, 2, 5, 15, 30, 45), time.time
    assert_equal ActiveSupport::TimeZone["Hawaii"], time.time_zone
  end

  def test_local_with_old_date
    time = ActiveSupport::TimeZone["Hawaii"].local(1850, 2, 5, 15, 30, 45)
    assert_equal [45, 30, 15, 5, 2, 1850], time.to_a[0, 6]
    assert_equal ActiveSupport::TimeZone["Hawaii"], time.time_zone
  end

  def test_local_enforces_spring_dst_rules
    zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    twz = zone.local(2006, 4, 2, 1, 59, 59) # 1 second before DST start
    assert_equal Time.utc(2006, 4, 2, 1, 59, 59), twz.time
    assert_equal Time.utc(2006, 4, 2, 6, 59, 59), twz.utc
    assert_equal false, twz.dst?
    assert_equal "EST", twz.zone
    twz2 = zone.local(2006, 4, 2, 2) # 2AM does not exist because at 2AM, time springs forward to 3AM
    assert_equal Time.utc(2006, 4, 2, 3), twz2.time # twz is created for 3AM
    assert_equal Time.utc(2006, 4, 2, 7), twz2.utc
    assert_equal true, twz2.dst?
    assert_equal "EDT", twz2.zone
    twz3 = zone.local(2006, 4, 2, 2, 30) # 2:30AM does not exist because at 2AM, time springs forward to 3AM
    assert_equal Time.utc(2006, 4, 2, 3, 30), twz3.time # twz is created for 3:30AM
    assert_equal Time.utc(2006, 4, 2, 7, 30), twz3.utc
    assert_equal true, twz3.dst?
    assert_equal "EDT", twz3.zone
  end

  def test_local_enforces_fall_dst_rules
    # 1AM during fall DST transition is ambiguous, it could be either DST or non-DST 1AM
    # Mirroring Time.local behavior, this method selects the DST time
    zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    twz = zone.local(2006, 10, 29, 1)
    assert_equal Time.utc(2006, 10, 29, 1), twz.time
    assert_equal Time.utc(2006, 10, 29, 5), twz.utc
    assert_equal true, twz.dst?
    assert_equal "EDT", twz.zone
  end

  def test_local_with_ambiguous_time
    zone = ActiveSupport::TimeZone["Moscow"]
    assert_equal Time.utc(2014, 10, 25, 22, 0, 0), zone.local(2014, 10, 26, 1, 0, 0)
  end

  def test_at
    zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    secs = 946684800.0
    twz = zone.at(secs)
    assert_equal Time.utc(1999, 12, 31, 19), twz.time
    assert_equal Time.utc(2000), twz.utc
    assert_equal zone, twz.time_zone
    assert_equal secs, twz.to_f
  end

  def test_at_with_old_date
    zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    secs = DateTime.civil(1850).to_f
    twz = zone.at(secs)
    assert_equal [1850, 1, 1, 0], [twz.utc.year, twz.utc.mon, twz.utc.day, twz.utc.hour]
    assert_equal zone, twz.time_zone
    assert_equal secs, twz.to_f
  end

  def test_at_with_microseconds
    zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    secs = 946684800.0
    microsecs = 123456.789
    twz = zone.at(secs, microsecs)
    assert_equal zone, twz.time_zone
    assert_equal secs, twz.to_i
    assert_equal 123456789, twz.nsec
  end

  def test_iso8601
    zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    twz = zone.iso8601("1999-12-31T19:00:00")
    assert_equal Time.utc(1999, 12, 31, 19), twz.time
    assert_equal Time.utc(2000), twz.utc
    assert_equal zone, twz.time_zone
  end

  def test_iso8601_with_fractional_seconds
    zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    twz = zone.iso8601("1999-12-31T19:00:00.750")
    assert_equal 750000, twz.time.usec
    assert_equal Time.utc(1999, 12, 31, 19, 0, 0 + Rational(3, 4)), twz.time
    assert_equal Time.utc(2000, 1, 1, 0, 0, 0 + Rational(3, 4)), twz.utc
    assert_equal zone, twz.time_zone
  end

  def test_iso8601_with_zone
    zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    twz = zone.iso8601("1999-12-31T14:00:00-10:00")
    assert_equal Time.utc(1999, 12, 31, 19), twz.time
    assert_equal Time.utc(2000), twz.utc
    assert_equal zone, twz.time_zone
  end

  def test_iso8601_with_invalid_string
    zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]

    exception = assert_raises(ArgumentError) do
      zone.iso8601("foobar")
    end

    assert_equal "invalid date", exception.message
  end

  def test_iso8601_with_missing_time_components
    zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    twz = zone.iso8601("1999-12-31")
    assert_equal Time.utc(1999, 12, 31, 0, 0, 0), twz.time
    assert_equal Time.utc(1999, 12, 31, 5, 0, 0), twz.utc
    assert_equal zone, twz.time_zone
  end

  def test_iso8601_with_old_date
    zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    twz = zone.iso8601("1883-12-31T19:00:00")
    assert_equal [0, 0, 19, 31, 12, 1883], twz.to_a[0, 6]
    assert_equal zone, twz.time_zone
  end

  def test_iso8601_far_future_date_with_time_zone_offset_in_string
    zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    twz = zone.iso8601("2050-12-31T19:00:00-10:00") # i.e., 2050-01-01 05:00:00 UTC
    assert_equal [0, 0, 0, 1, 1, 2051], twz.to_a[0, 6]
    assert_equal zone, twz.time_zone
  end

  def test_iso8601_should_not_black_out_system_timezone_dst_jump
    with_env_tz("EET") do
      zone = ActiveSupport::TimeZone["Pacific Time (US & Canada)"]
      twz = zone.iso8601("2012-03-25T03:29:00")
      assert_equal [0, 29, 3, 25, 3, 2012], twz.to_a[0, 6]
    end
  end

  def test_iso8601_should_black_out_app_timezone_dst_jump
    with_env_tz("EET") do
      zone = ActiveSupport::TimeZone["Pacific Time (US & Canada)"]
      twz = zone.iso8601("2012-03-11T02:29:00")
      assert_equal [0, 29, 3, 11, 3, 2012], twz.to_a[0, 6]
    end
  end

  def test_iso8601_doesnt_use_local_dst
    with_env_tz "US/Eastern" do
      zone = ActiveSupport::TimeZone["UTC"]
      twz = zone.iso8601("2013-03-10T02:00:00")
      assert_equal Time.utc(2013, 3, 10, 2, 0, 0), twz.time
    end
  end

  def test_iso8601_handles_dst_jump
    with_env_tz "US/Eastern" do
      zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
      twz = zone.iso8601("2013-03-10T02:00:00")
      assert_equal Time.utc(2013, 3, 10, 3, 0, 0), twz.time
    end
  end

  def test_iso8601_with_ambiguous_time
    zone = ActiveSupport::TimeZone["Moscow"]
    assert_equal Time.utc(2014, 10, 25, 22, 0, 0), zone.parse("2014-10-26T01:00:00")
  end

  def test_iso8601_with_invalid_value_parseable_by_date__iso8601
    zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]

    exception = assert_raises(ArgumentError) do
      zone.iso8601("12936")
    end

    assert_equal "invalid date", exception.message
  end

  def test_parse
    zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    twz = zone.parse("1999-12-31 19:00:00")
    assert_equal Time.utc(1999, 12, 31, 19), twz.time
    assert_equal Time.utc(2000), twz.utc
    assert_equal zone, twz.time_zone
  end

  def test_parse_string_with_timezone
    (-11..13).each do |timezone_offset|
      zone = ActiveSupport::TimeZone[timezone_offset]
      twz = zone.parse("1999-12-31 19:00:00")
      assert_equal twz, zone.parse(twz.to_s)
    end
  end

  def test_parse_with_old_date
    zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    twz = zone.parse("1883-12-31 19:00:00")
    assert_equal [0, 0, 19, 31, 12, 1883], twz.to_a[0, 6]
    assert_equal zone, twz.time_zone
  end

  def test_parse_far_future_date_with_time_zone_offset_in_string
    zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    twz = zone.parse("2050-12-31 19:00:00 -10:00") # i.e., 2050-01-01 05:00:00 UTC
    assert_equal [0, 0, 0, 1, 1, 2051], twz.to_a[0, 6]
    assert_equal zone, twz.time_zone
  end

  def test_parse_returns_nil_when_string_without_date_information_is_passed_in
    zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    assert_nil zone.parse("foobar")
    assert_nil zone.parse("   ")
  end

  def test_parse_with_incomplete_date
    zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    zone.stub(:now, zone.local(1999, 12, 31)) do
      twz = zone.parse("19:00:00")
      assert_equal Time.utc(1999, 12, 31, 19), twz.time
    end
  end

  def test_parse_with_day_omitted
    with_env_tz "US/Eastern" do
      zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
      assert_equal Time.local(2000, 2, 1), zone.parse("Feb", Time.local(2000, 1, 1))
      assert_equal Time.local(2005, 2, 1), zone.parse("Feb 2005", Time.local(2000, 1, 1))
      assert_equal Time.local(2005, 2, 2), zone.parse("2 Feb 2005", Time.local(2000, 1, 1))
    end
  end

  def test_parse_should_not_black_out_system_timezone_dst_jump
    with_env_tz("EET") do
      zone = ActiveSupport::TimeZone["Pacific Time (US & Canada)"]
      twz = zone.parse("2012-03-25 03:29:00")
      assert_equal [0, 29, 3, 25, 3, 2012], twz.to_a[0, 6]
    end
  end

  def test_parse_should_black_out_app_timezone_dst_jump
    with_env_tz("EET") do
      zone = ActiveSupport::TimeZone["Pacific Time (US & Canada)"]
      twz = zone.parse("2012-03-11 02:29:00")
      assert_equal [0, 29, 3, 11, 3, 2012], twz.to_a[0, 6]
    end
  end

  def test_parse_with_missing_time_components
    zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    zone.stub(:now, zone.local(1999, 12, 31, 12, 59, 59)) do
      twz = zone.parse("2012-12-01")
      assert_equal Time.utc(2012, 12, 1), twz.time
    end
  end

  def test_parse_with_javascript_date
    zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    twz = zone.parse("Mon May 28 2012 00:00:00 GMT-0700 (PDT)")
    assert_equal Time.utc(2012, 5, 28, 7, 0, 0), twz.utc
  end

  def test_parse_doesnt_use_local_dst
    with_env_tz "US/Eastern" do
      zone = ActiveSupport::TimeZone["UTC"]
      twz = zone.parse("2013-03-10 02:00:00")
      assert_equal Time.utc(2013, 3, 10, 2, 0, 0), twz.time
    end
  end

  def test_parse_handles_dst_jump
    with_env_tz "US/Eastern" do
      zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
      twz = zone.parse("2013-03-10 02:00:00")
      assert_equal Time.utc(2013, 3, 10, 3, 0, 0), twz.time
    end
  end

  def test_parse_with_invalid_date
    zone = ActiveSupport::TimeZone["UTC"]

    exception = assert_raises(ArgumentError) do
      zone.parse("9000")
    end

    assert_equal "argument out of range", exception.message
  end

  def test_parse_with_ambiguous_time
    zone = ActiveSupport::TimeZone["Moscow"]
    assert_equal Time.utc(2014, 10, 25, 22, 0, 0), zone.parse("2014-10-26 01:00:00")
  end

  def test_rfc3339
    zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    twz = zone.rfc3339("1999-12-31T14:00:00-10:00")
    assert_equal Time.utc(1999, 12, 31, 19), twz.time
    assert_equal Time.utc(2000), twz.utc
    assert_equal zone, twz.time_zone
  end

  def test_rfc3339_with_fractional_seconds
    zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    twz = zone.iso8601("1999-12-31T14:00:00.750-10:00")
    assert_equal 750000, twz.time.usec
    assert_equal Time.utc(1999, 12, 31, 19, 0, 0 + Rational(3, 4)), twz.time
    assert_equal Time.utc(2000, 1, 1, 0, 0, 0 + Rational(3, 4)), twz.utc
    assert_equal zone, twz.time_zone
  end

  def test_rfc3339_with_missing_time
    zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]

    exception = assert_raises(ArgumentError) do
      zone.rfc3339("1999-12-31")
    end

    assert_equal "invalid date", exception.message
  end

  def test_rfc3339_with_missing_offset
    zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]

    exception = assert_raises(ArgumentError) do
      zone.rfc3339("1999-12-31T19:00:00")
    end

    assert_equal "invalid date", exception.message
  end

  def test_rfc3339_with_invalid_string
    zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]

    exception = assert_raises(ArgumentError) do
      zone.rfc3339("foobar")
    end

    assert_equal "invalid date", exception.message
  end

  def test_rfc3339_with_old_date
    zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    twz = zone.rfc3339("1883-12-31T19:00:00-05:00")
    assert_equal [0, 0, 19, 31, 12, 1883], twz.to_a[0, 6]
    assert_equal zone, twz.time_zone
  end

  def test_rfc3339_far_future_date_with_time_zone_offset_in_string
    zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    twz = zone.rfc3339("2050-12-31T19:00:00-10:00") # i.e., 2050-01-01 05:00:00 UTC
    assert_equal [0, 0, 0, 1, 1, 2051], twz.to_a[0, 6]
    assert_equal zone, twz.time_zone
  end

  def test_rfc3339_should_not_black_out_system_timezone_dst_jump
    with_env_tz("EET") do
      zone = ActiveSupport::TimeZone["Pacific Time (US & Canada)"]
      twz = zone.rfc3339("2012-03-25T03:29:00-07:00")
      assert_equal [0, 29, 3, 25, 3, 2012], twz.to_a[0, 6]
    end
  end

  def test_rfc3339_should_black_out_app_timezone_dst_jump
    with_env_tz("EET") do
      zone = ActiveSupport::TimeZone["Pacific Time (US & Canada)"]
      twz = zone.rfc3339("2012-03-11T02:29:00-08:00")
      assert_equal [0, 29, 3, 11, 3, 2012], twz.to_a[0, 6]
    end
  end

  def test_rfc3339_doesnt_use_local_dst
    with_env_tz "US/Eastern" do
      zone = ActiveSupport::TimeZone["UTC"]
      twz = zone.rfc3339("2013-03-10T02:00:00Z")
      assert_equal Time.utc(2013, 3, 10, 2, 0, 0), twz.time
    end
  end

  def test_rfc3339_handles_dst_jump
    with_env_tz "US/Eastern" do
      zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
      twz = zone.iso8601("2013-03-10T02:00:00-05:00")
      assert_equal Time.utc(2013, 3, 10, 3, 0, 0), twz.time
    end
  end

  def test_strptime
    zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    twz = zone.strptime("1999-12-31 12:00:00", "%Y-%m-%d %H:%M:%S")
    assert_equal Time.utc(1999, 12, 31, 17), twz
    assert_equal Time.utc(1999, 12, 31, 12), twz.time
    assert_equal Time.utc(1999, 12, 31, 17), twz.utc
    assert_equal zone, twz.time_zone
  end

  def test_strptime_with_nondefault_time_zone
    with_tz_default ActiveSupport::TimeZone["Pacific Time (US & Canada)"] do
      zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
      twz = zone.strptime("1999-12-31 12:00:00", "%Y-%m-%d %H:%M:%S")
      assert_equal Time.utc(1999, 12, 31, 17), twz
      assert_equal Time.utc(1999, 12, 31, 12), twz.time
      assert_equal Time.utc(1999, 12, 31, 17), twz.utc
      assert_equal zone, twz.time_zone
    end
  end

  def test_strptime_with_explicit_time_zone_as_abbrev
    zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    twz = zone.strptime("1999-12-31 12:00:00 PST", "%Y-%m-%d %H:%M:%S %Z")
    assert_equal Time.utc(1999, 12, 31, 20), twz
    assert_equal Time.utc(1999, 12, 31, 15), twz.time
    assert_equal Time.utc(1999, 12, 31, 20), twz.utc
    assert_equal zone, twz.time_zone
  end

  def test_strptime_with_explicit_time_zone_as_h_offset
    zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    twz = zone.strptime("1999-12-31 12:00:00 -08", "%Y-%m-%d %H:%M:%S %:::z")
    assert_equal Time.utc(1999, 12, 31, 20), twz
    assert_equal Time.utc(1999, 12, 31, 15), twz.time
    assert_equal Time.utc(1999, 12, 31, 20), twz.utc
    assert_equal zone, twz.time_zone
  end

  def test_strptime_with_explicit_time_zone_as_hm_offset
    zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    twz = zone.strptime("1999-12-31 12:00:00 -08:00", "%Y-%m-%d %H:%M:%S %:z")
    assert_equal Time.utc(1999, 12, 31, 20), twz
    assert_equal Time.utc(1999, 12, 31, 15), twz.time
    assert_equal Time.utc(1999, 12, 31, 20), twz.utc
    assert_equal zone, twz.time_zone
  end

  def test_strptime_with_explicit_time_zone_as_hms_offset
    zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    twz = zone.strptime("1999-12-31 12:00:00 -08:00:00", "%Y-%m-%d %H:%M:%S %::z")
    assert_equal Time.utc(1999, 12, 31, 20), twz
    assert_equal Time.utc(1999, 12, 31, 15), twz.time
    assert_equal Time.utc(1999, 12, 31, 20), twz.utc
    assert_equal zone, twz.time_zone
  end

  def test_strptime_with_almost_explicit_time_zone
    zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    twz = zone.strptime("1999-12-31 12:00:00 %Z", "%Y-%m-%d %H:%M:%S %%Z")
    assert_equal Time.utc(1999, 12, 31, 17), twz
    assert_equal Time.utc(1999, 12, 31, 12), twz.time
    assert_equal Time.utc(1999, 12, 31, 17), twz.utc
    assert_equal zone, twz.time_zone
  end

  def test_strptime_with_day_omitted
    with_env_tz "US/Eastern" do
      zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
      assert_equal Time.local(2000, 2, 1), zone.strptime("Feb", "%b", Time.local(2000, 1, 1))
      assert_equal Time.local(2005, 2, 1), zone.strptime("Feb 2005", "%b %Y", Time.local(2000, 1, 1))
      assert_equal Time.local(2005, 2, 2), zone.strptime("2 Feb 2005", "%e %b %Y", Time.local(2000, 1, 1))
    end
  end

  def test_strptime_with_malformed_string
    with_env_tz "US/Eastern" do
      zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
      assert_raise(ArgumentError) { zone.strptime("1999-12-31", "%Y/%m/%d") }
    end
  end

  def test_strptime_with_timestamp_seconds
    with_env_tz "US/Eastern" do
      zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
      time_str = "1470272280"
      time = zone.strptime(time_str, "%s")
      assert_equal Time.at(1470272280), time
    end
  end

  def test_strptime_with_timestamp_milliseconds
    with_env_tz "US/Eastern" do
      zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
      time_str = "1470272280000"
      time = zone.strptime(time_str, "%Q")
      assert_equal Time.at(1470272280), time
    end
  end

  def test_strptime_with_ambiguous_time
    zone = ActiveSupport::TimeZone["Moscow"]
    assert_equal Time.utc(2014, 10, 25, 22, 0, 0), zone.strptime("2014-10-26 01:00:00", "%Y-%m-%d %H:%M:%S")
  end

  def test_utc_offset_lazy_loaded_from_tzinfo_when_not_passed_in_to_initialize
    tzinfo = TZInfo::Timezone.get("America/New_York")
    zone = ActiveSupport::TimeZone.create(tzinfo.name, nil, tzinfo)
    assert_nil zone.instance_variable_get("@utc_offset")
    assert_equal(-18_000, zone.utc_offset)
  end

  def test_utc_offset_is_not_cached_when_current_period_gets_stale
    tz = ActiveSupport::TimeZone.create("Moscow")
    travel_to(Time.utc(2014, 10, 25, 21)) do # 1 hour before TZ change
      assert_equal 14400, tz.utc_offset, "utc_offset should be initialized according to current_period"
    end

    travel_to(Time.utc(2014, 10, 25, 22)) do # after TZ change
      assert_equal 10800, tz.utc_offset, "utc_offset should not be cached when current_period gets stale"
    end
  end

  def test_seconds_to_utc_offset_with_colon
    assert_equal "-06:00", ActiveSupport::TimeZone.seconds_to_utc_offset(-21_600)
    assert_equal "+00:00", ActiveSupport::TimeZone.seconds_to_utc_offset(0)
    assert_equal "+05:00", ActiveSupport::TimeZone.seconds_to_utc_offset(18_000)
  end

  def test_seconds_to_utc_offset_without_colon
    assert_equal "-0600", ActiveSupport::TimeZone.seconds_to_utc_offset(-21_600, false)
    assert_equal "+0000", ActiveSupport::TimeZone.seconds_to_utc_offset(0, false)
    assert_equal "+0500", ActiveSupport::TimeZone.seconds_to_utc_offset(18_000, false)
  end

  def test_seconds_to_utc_offset_with_negative_offset
    assert_equal "-01:00", ActiveSupport::TimeZone.seconds_to_utc_offset(-3_600)
    assert_equal "-00:59", ActiveSupport::TimeZone.seconds_to_utc_offset(-3_599)
    assert_equal "-05:30", ActiveSupport::TimeZone.seconds_to_utc_offset(-19_800)
  end

  def test_formatted_offset_positive
    zone = ActiveSupport::TimeZone["New Delhi"]
    assert_equal "+05:30", zone.formatted_offset
    assert_equal "+0530", zone.formatted_offset(false)
  end

  def test_formatted_offset_negative
    zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    assert_equal "-05:00", zone.formatted_offset
    assert_equal "-0500", zone.formatted_offset(false)
  end

  def test_z_format_strings
    zone = ActiveSupport::TimeZone["Tokyo"]
    twz = zone.now
    assert_equal "+0900",     twz.strftime("%z")
    assert_equal "+09:00",    twz.strftime("%:z")
    assert_equal "+09:00:00", twz.strftime("%::z")
  end

  def test_formatted_offset_zero
    zone = ActiveSupport::TimeZone["London"]
    assert_equal "+00:00", zone.formatted_offset
    assert_equal "UTC", zone.formatted_offset(true, "UTC")
  end

  def test_zone_compare
    zone1 = ActiveSupport::TimeZone["Central Time (US & Canada)"] # offset -0600
    zone2 = ActiveSupport::TimeZone["Eastern Time (US & Canada)"] # offset -0500
    assert zone1 < zone2
    assert zone2 > zone1
    assert zone1 == zone1
  end

  def test_zone_match
    zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    assert zone =~ /Eastern/
    assert zone =~ /New_York/
    assert zone !~ /Nonexistent_Place/
  end

  def test_zone_match?
    zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    assert zone.match?(/Eastern/)
    assert zone.match?(/New_York/)
    assert_not zone.match?(/Nonexistent_Place/)
  end

  def test_to_s
    assert_equal "(GMT+05:30) New Delhi", ActiveSupport::TimeZone["New Delhi"].to_s
  end

  def test_all_sorted
    all = ActiveSupport::TimeZone.all
    1.upto(all.length - 1) do |i|
      assert all[i - 1] < all[i]
    end
  end

  def test_all_uninfluenced_by_time_zone_lookups_delegated_to_tzinfo
    ActiveSupport::TimeZone.clear
    galapagos = ActiveSupport::TimeZone["Pacific/Galapagos"]
    all_zones = ActiveSupport::TimeZone.all
    assert_not_includes all_zones, galapagos
  end

  def test_all_doesnt_raise_exception_with_missing_tzinfo_data
    mappings = {
      "Puerto Rico" => "America/Unknown",
      "Pittsburgh"  => "America/New_York"
    }

    with_tz_mappings(mappings) do
      assert_nil ActiveSupport::TimeZone["Puerto Rico"]
      assert_nil ActiveSupport::TimeZone[-9]
      assert_nothing_raised do
        ActiveSupport::TimeZone.all
      end
    end
  end

  def test_index
    assert_nil ActiveSupport::TimeZone["bogus"]
    assert_instance_of ActiveSupport::TimeZone, ActiveSupport::TimeZone["Central Time (US & Canada)"]
    assert_instance_of ActiveSupport::TimeZone, ActiveSupport::TimeZone[8]
    assert_raise(ArgumentError) { ActiveSupport::TimeZone[false] }
  end

  def test_unknown_zone_raises_exception
    assert_raise TZInfo::InvalidTimezoneIdentifier do
      ActiveSupport::TimeZone.create("bogus")
    end
  end

  def test_unknown_zones_dont_store_mapping_keys
    assert_nil ActiveSupport::TimeZone["bogus"]
  end

  def test_new
    assert_equal ActiveSupport::TimeZone["Central Time (US & Canada)"], ActiveSupport::TimeZone.new("Central Time (US & Canada)")
  end

  def test_us_zones
    assert_includes ActiveSupport::TimeZone.us_zones, ActiveSupport::TimeZone["Hawaii"]
    assert_not_includes ActiveSupport::TimeZone.us_zones, ActiveSupport::TimeZone["Kuala Lumpur"]
  end

  def test_country_zones
    assert_includes ActiveSupport::TimeZone.country_zones("ru"), ActiveSupport::TimeZone["Moscow"]
    assert_not_includes ActiveSupport::TimeZone.country_zones(:ru), ActiveSupport::TimeZone["Kuala Lumpur"]
  end

  def test_country_zones_with_and_without_mappings
    assert_includes ActiveSupport::TimeZone.country_zones("au"), ActiveSupport::TimeZone["Adelaide"]
    assert_includes ActiveSupport::TimeZone.country_zones("au"), ActiveSupport::TimeZone["Australia/Lord_Howe"]
  end

  def test_country_zones_with_multiple_mappings
    assert_includes ActiveSupport::TimeZone.country_zones("gb"), ActiveSupport::TimeZone["Edinburgh"]
    assert_includes ActiveSupport::TimeZone.country_zones("gb"), ActiveSupport::TimeZone["London"]
  end

  def test_country_zones_without_mappings
    assert_includes ActiveSupport::TimeZone.country_zones(:sv), ActiveSupport::TimeZone["America/El_Salvador"]
  end

  def test_to_yaml
    assert_equal("--- !ruby/object:ActiveSupport::TimeZone\nname: Pacific/Honolulu\n", ActiveSupport::TimeZone["Hawaii"].to_yaml)
    assert_equal("--- !ruby/object:ActiveSupport::TimeZone\nname: Europe/London\n", ActiveSupport::TimeZone["Europe/London"].to_yaml)
  end

  def test_yaml_load
    assert_equal(ActiveSupport::TimeZone["Pacific/Honolulu"], YAML.load("--- !ruby/object:ActiveSupport::TimeZone\nname: Pacific/Honolulu\n"))
  end
end
