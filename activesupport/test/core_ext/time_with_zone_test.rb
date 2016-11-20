require "abstract_unit"
require "active_support/time"
require "time_zone_test_helpers"
require "active_support/core_ext/string/strip"
require "yaml"

class TimeWithZoneTest < ActiveSupport::TestCase
  include TimeZoneTestHelpers

  def setup
    @utc = Time.utc(2000, 1, 1, 0)
    @time_zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    @twz = ActiveSupport::TimeWithZone.new(@utc, @time_zone)
    @dt_twz = ActiveSupport::TimeWithZone.new(@utc.to_datetime, @time_zone)
  end

  def test_utc
    assert_equal @utc, @twz.utc
    assert_instance_of Time, @twz.utc
    assert_instance_of Time, @dt_twz.utc
  end

  def test_time
    assert_equal Time.utc(1999, 12, 31, 19), @twz.time
  end

  def test_time_zone
    assert_equal @time_zone, @twz.time_zone
  end

  def test_in_time_zone
    Time.use_zone "Alaska" do
      assert_equal ActiveSupport::TimeWithZone.new(@utc, ActiveSupport::TimeZone["Alaska"]), @twz.in_time_zone
    end
  end

  def test_in_time_zone_with_argument
    assert_equal ActiveSupport::TimeWithZone.new(@utc, ActiveSupport::TimeZone["Alaska"]), @twz.in_time_zone("Alaska")
  end

  def test_in_time_zone_with_new_zone_equal_to_old_zone_does_not_create_new_object
    assert_equal @twz.object_id, @twz.in_time_zone(ActiveSupport::TimeZone["Eastern Time (US & Canada)"]).object_id
  end

  def test_in_time_zone_with_bad_argument
    assert_raise(ArgumentError) { @twz.in_time_zone("No such timezone exists") }
    assert_raise(ArgumentError) { @twz.in_time_zone(-15.hours) }
    assert_raise(ArgumentError) { @twz.in_time_zone(Object.new) }
  end

  def test_localtime
    assert_equal @twz.localtime, @twz.utc.getlocal
    assert_instance_of Time, @twz.localtime
    assert_instance_of Time, @dt_twz.localtime
  end

  def test_utc?
    assert_equal false, @twz.utc?

    assert_equal true, ActiveSupport::TimeWithZone.new(Time.utc(2000), ActiveSupport::TimeZone["UTC"]).utc?
    assert_equal true, ActiveSupport::TimeWithZone.new(Time.utc(2000), ActiveSupport::TimeZone["Etc/UTC"]).utc?
    assert_equal true, ActiveSupport::TimeWithZone.new(Time.utc(2000), ActiveSupport::TimeZone["Universal"]).utc?
    assert_equal true, ActiveSupport::TimeWithZone.new(Time.utc(2000), ActiveSupport::TimeZone["UCT"]).utc?
    assert_equal true, ActiveSupport::TimeWithZone.new(Time.utc(2000), ActiveSupport::TimeZone["Etc/UCT"]).utc?
    assert_equal true, ActiveSupport::TimeWithZone.new(Time.utc(2000), ActiveSupport::TimeZone["Etc/Universal"]).utc?

    assert_equal false, ActiveSupport::TimeWithZone.new(Time.utc(2000), ActiveSupport::TimeZone["Africa/Abidjan"]).utc?
    assert_equal false, ActiveSupport::TimeWithZone.new(Time.utc(2000), ActiveSupport::TimeZone["Africa/Banjul"]).utc?
    assert_equal false, ActiveSupport::TimeWithZone.new(Time.utc(2000), ActiveSupport::TimeZone["Africa/Freetown"]).utc?
    assert_equal false, ActiveSupport::TimeWithZone.new(Time.utc(2000), ActiveSupport::TimeZone["GMT"]).utc?
    assert_equal false, ActiveSupport::TimeWithZone.new(Time.utc(2000), ActiveSupport::TimeZone["GMT0"]).utc?
    assert_equal false, ActiveSupport::TimeWithZone.new(Time.utc(2000), ActiveSupport::TimeZone["Greenwich"]).utc?
    assert_equal false, ActiveSupport::TimeWithZone.new(Time.utc(2000), ActiveSupport::TimeZone["Iceland"]).utc?
    assert_equal false, ActiveSupport::TimeWithZone.new(Time.utc(2000), ActiveSupport::TimeZone["Africa/Monrovia"]).utc?
  end

  def test_formatted_offset
    assert_equal "-05:00", @twz.formatted_offset
    assert_equal "-04:00", ActiveSupport::TimeWithZone.new(Time.utc(2000, 6), @time_zone).formatted_offset #dst
  end

  def test_dst?
    assert_equal false, @twz.dst?
    assert_equal true, ActiveSupport::TimeWithZone.new(Time.utc(2000, 6), @time_zone).dst?
  end

  def test_zone
    assert_equal "EST", @twz.zone
    assert_equal "EDT", ActiveSupport::TimeWithZone.new(Time.utc(2000, 6), @time_zone).zone #dst
  end

  def test_nsec
    local     = Time.local(2011, 6, 7, 23, 59, 59, Rational(999999999, 1000))
    with_zone = ActiveSupport::TimeWithZone.new(nil, ActiveSupport::TimeZone["Hawaii"], local)

    assert_equal local.nsec, with_zone.nsec
    assert_equal with_zone.nsec, 999999999
  end

  def test_strftime
    assert_equal "1999-12-31 19:00:00 EST -0500", @twz.strftime("%Y-%m-%d %H:%M:%S %Z %z")
  end

  def test_strftime_with_escaping
    assert_equal "%Z %z", @twz.strftime("%%Z %%z")
    assert_equal "%EST %-0500", @twz.strftime("%%%Z %%%z")
  end

  def test_inspect
    assert_equal "Fri, 31 Dec 1999 19:00:00 EST -05:00", @twz.inspect
  end

  def test_to_s
    assert_equal "1999-12-31 19:00:00 -0500", @twz.to_s
  end

  def test_to_formatted_s
    assert_equal "1999-12-31 19:00:00 -0500", @twz.to_formatted_s
  end

  def test_to_s_db
    assert_equal "2000-01-01 00:00:00", @twz.to_s(:db)
  end

  def test_xmlschema
    assert_equal "1999-12-31T19:00:00-05:00", @twz.xmlschema
  end

  def test_xmlschema_with_fractional_seconds
    @twz += 0.1234560001 # advance the time by a fraction of a second
    assert_equal "1999-12-31T19:00:00.123-05:00", @twz.xmlschema(3)
    assert_equal "1999-12-31T19:00:00.123456-05:00", @twz.xmlschema(6)
    assert_equal "1999-12-31T19:00:00.123456000100-05:00", @twz.xmlschema(12)
  end

  def test_xmlschema_with_fractional_seconds_lower_than_hundred_thousand
    @twz += 0.001234 # advance the time by a fraction
    assert_equal "1999-12-31T19:00:00.001-05:00", @twz.xmlschema(3)
    assert_equal "1999-12-31T19:00:00.001234-05:00", @twz.xmlschema(6)
    assert_equal "1999-12-31T19:00:00.001234000000-05:00", @twz.xmlschema(12)
  end

  def test_xmlschema_with_nil_fractional_seconds
    assert_equal "1999-12-31T19:00:00-05:00", @twz.xmlschema(nil)
  end

  def test_to_yaml
    yaml = <<-EOF.strip_heredoc
      --- !ruby/object:ActiveSupport::TimeWithZone
      utc: 2000-01-01 00:00:00.000000000 Z
      zone: !ruby/object:ActiveSupport::TimeZone
        name: America/New_York
      time: 1999-12-31 19:00:00.000000000 Z
    EOF

    assert_equal(yaml, @twz.to_yaml)
  end

  def test_ruby_to_yaml
    yaml = <<-EOF.strip_heredoc
      ---
      twz: !ruby/object:ActiveSupport::TimeWithZone
        utc: 2000-01-01 00:00:00.000000000 Z
        zone: !ruby/object:ActiveSupport::TimeZone
          name: America/New_York
        time: 1999-12-31 19:00:00.000000000 Z
    EOF

    assert_equal(yaml, { "twz" => @twz }.to_yaml)
  end

  def test_yaml_load
    yaml = <<-EOF.strip_heredoc
      --- !ruby/object:ActiveSupport::TimeWithZone
      utc: 2000-01-01 00:00:00.000000000 Z
      zone: !ruby/object:ActiveSupport::TimeZone
        name: America/New_York
      time: 1999-12-31 19:00:00.000000000 Z
    EOF

    assert_equal(@twz, YAML.load(yaml))
  end

  def test_ruby_yaml_load
    yaml = <<-EOF.strip_heredoc
      ---
      twz: !ruby/object:ActiveSupport::TimeWithZone
        utc: 2000-01-01 00:00:00.000000000 Z
        zone: !ruby/object:ActiveSupport::TimeZone
          name: America/New_York
        time: 1999-12-31 19:00:00.000000000 Z
    EOF

    assert_equal({ "twz" => @twz }, YAML.load(yaml))
  end

  def test_httpdate
    assert_equal "Sat, 01 Jan 2000 00:00:00 GMT", @twz.httpdate
  end

  def test_rfc2822
    assert_equal "Fri, 31 Dec 1999 19:00:00 -0500", @twz.rfc2822
  end

  def test_compare_with_time
    assert_equal  1, @twz <=> Time.utc(1999, 12, 31, 23, 59, 59)
    assert_equal  0, @twz <=> Time.utc(2000, 1, 1, 0, 0, 0)
    assert_equal(-1, @twz <=> Time.utc(2000, 1, 1, 0, 0, 1))
  end

  def test_compare_with_datetime
    assert_equal  1, @twz <=> DateTime.civil(1999, 12, 31, 23, 59, 59)
    assert_equal  0, @twz <=> DateTime.civil(2000, 1, 1, 0, 0, 0)
    assert_equal(-1, @twz <=> DateTime.civil(2000, 1, 1, 0, 0, 1))
  end

  def test_compare_with_time_with_zone
    assert_equal  1, @twz <=> ActiveSupport::TimeWithZone.new(Time.utc(1999, 12, 31, 23, 59, 59), ActiveSupport::TimeZone["UTC"])
    assert_equal  0, @twz <=> ActiveSupport::TimeWithZone.new(Time.utc(2000, 1, 1, 0, 0, 0), ActiveSupport::TimeZone["UTC"])
    assert_equal(-1, @twz <=> ActiveSupport::TimeWithZone.new(Time.utc(2000, 1, 1, 0, 0, 1), ActiveSupport::TimeZone["UTC"]))
  end

  def test_between?
    assert @twz.between?(Time.utc(1999, 12, 31, 23, 59, 59), Time.utc(2000, 1, 1, 0, 0, 1))
    assert_equal false, @twz.between?(Time.utc(2000, 1, 1, 0, 0, 1), Time.utc(2000, 1, 1, 0, 0, 2))
  end

  def test_today
    Date.stub(:current, Date.new(2000, 1, 1)) do
      assert_equal false, ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(1999, 12, 31, 23, 59, 59)).today?
      assert_equal true, ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2000, 1, 1, 0)).today?
      assert_equal true, ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2000, 1, 1, 23, 59, 59)).today?
      assert_equal false, ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2000, 1, 2, 0)).today?
    end
  end

  def test_past_with_time_current_as_time_local
    with_env_tz "US/Eastern" do
      Time.stub(:current, Time.local(2005, 2, 10, 15, 30, 45)) do
        assert_equal true, ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.local(2005, 2, 10, 15, 30, 44)).past?
        assert_equal false, ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.local(2005, 2, 10, 15, 30, 45)).past?
        assert_equal false, ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.local(2005, 2, 10, 15, 30, 46)).past?
      end
    end
  end

  def test_past_with_time_current_as_time_with_zone
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.local(2005, 2, 10, 15, 30, 45))
    Time.stub(:current, twz) do
      assert_equal true, ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.local(2005, 2, 10, 15, 30, 44)).past?
      assert_equal false, ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.local(2005, 2, 10, 15, 30, 45)).past?
      assert_equal false, ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.local(2005, 2, 10, 15, 30, 46)).past?
    end
  end

  def test_future_with_time_current_as_time_local
    with_env_tz "US/Eastern" do
      Time.stub(:current, Time.local(2005, 2, 10, 15, 30, 45)) do
        assert_equal false, ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.local(2005, 2, 10, 15, 30, 44)).future?
        assert_equal false, ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.local(2005, 2, 10, 15, 30, 45)).future?
        assert_equal true, ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.local(2005, 2, 10, 15, 30, 46)).future?
      end
    end
  end

  def test_future_with_time_current_as_time_with_zone
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.local(2005, 2, 10, 15, 30, 45))
    Time.stub(:current, twz) do
      assert_equal false, ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.local(2005, 2, 10, 15, 30, 44)).future?
      assert_equal false, ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.local(2005, 2, 10, 15, 30, 45)).future?
      assert_equal true, ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.local(2005, 2, 10, 15, 30, 46)).future?
    end
  end

  def test_eql?
    assert_equal true, @twz.eql?(@twz.dup)
    assert_equal true, @twz.eql?(Time.utc(2000))
    assert_equal true, @twz.eql?(ActiveSupport::TimeWithZone.new(Time.utc(2000), ActiveSupport::TimeZone["Hawaii"]))
    assert_equal false, @twz.eql?(Time.utc(2000, 1, 1, 0, 0, 1))
    assert_equal false, @twz.eql?(DateTime.civil(1999, 12, 31, 23, 59, 59))

    other_twz = ActiveSupport::TimeWithZone.new(DateTime.now.utc, @time_zone)
    assert_equal true, other_twz.eql?(other_twz.dup)
  end

  def test_hash
    assert_equal Time.utc(2000).hash, @twz.hash
    assert_equal Time.utc(2000).hash, ActiveSupport::TimeWithZone.new(Time.utc(2000), ActiveSupport::TimeZone["Hawaii"]).hash
  end

  def test_plus_with_integer
    assert_equal Time.utc(1999, 12, 31, 19, 0 , 5), (@twz + 5).time
  end

  def test_plus_with_integer_when_self_wraps_datetime
    datetime = DateTime.civil(2000, 1, 1, 0)
    twz = ActiveSupport::TimeWithZone.new(datetime, @time_zone)
    assert_equal DateTime.civil(1999, 12, 31, 19, 0 , 5), (twz + 5).time
  end

  def test_plus_when_crossing_time_class_limit
    twz = ActiveSupport::TimeWithZone.new(Time.utc(2038, 1, 19), @time_zone)
    assert_equal [0, 0, 19, 19, 1, 2038], (twz + 86_400).to_a[0, 6]
  end

  def test_plus_with_duration
    assert_equal Time.utc(2000, 1, 5, 19, 0 , 0), (@twz + 5.days).time
  end

  def test_minus_with_integer
    assert_equal Time.utc(1999, 12, 31, 18, 59 , 55), (@twz - 5).time
  end

  def test_minus_with_integer_when_self_wraps_datetime
    datetime = DateTime.civil(2000, 1, 1, 0)
    twz = ActiveSupport::TimeWithZone.new(datetime, @time_zone)
    assert_equal DateTime.civil(1999, 12, 31, 18, 59 , 55), (twz - 5).time
  end

  def test_minus_with_duration
    assert_equal Time.utc(1999, 12, 26, 19, 0 , 0), (@twz - 5.days).time
  end

  def test_minus_with_time
    assert_equal  86_400.0,  ActiveSupport::TimeWithZone.new(Time.utc(2000, 1, 2), ActiveSupport::TimeZone["UTC"]) - Time.utc(2000, 1, 1)
    assert_equal  86_400.0,  ActiveSupport::TimeWithZone.new(Time.utc(2000, 1, 2), ActiveSupport::TimeZone["Hawaii"]) - Time.utc(2000, 1, 1)
  end

  def test_minus_with_time_precision
    assert_equal  86_399.999999998,  ActiveSupport::TimeWithZone.new(Time.utc(2000, 1, 2, 23, 59, 59, Rational(999999999, 1000)), ActiveSupport::TimeZone["UTC"]) - Time.utc(2000, 1, 2, 0, 0, 0, Rational(1, 1000))
    assert_equal  86_399.999999998,  ActiveSupport::TimeWithZone.new(Time.utc(2000, 1, 2, 23, 59, 59, Rational(999999999, 1000)), ActiveSupport::TimeZone["Hawaii"]) - Time.utc(2000, 1, 2, 0, 0, 0, Rational(1, 1000))
  end

  def test_minus_with_time_with_zone
    twz1 = ActiveSupport::TimeWithZone.new(Time.utc(2000, 1, 1), ActiveSupport::TimeZone["UTC"])
    twz2 = ActiveSupport::TimeWithZone.new(Time.utc(2000, 1, 2), ActiveSupport::TimeZone["UTC"])
    assert_equal 86_400.0,  twz2 - twz1
  end

  def test_minus_with_time_with_zone_precision
    twz1 = ActiveSupport::TimeWithZone.new(Time.utc(2000, 1, 1, 0, 0, 0, Rational(1, 1000)), ActiveSupport::TimeZone["UTC"])
    twz2 = ActiveSupport::TimeWithZone.new(Time.utc(2000, 1, 1, 23, 59, 59, Rational(999999999, 1000)), ActiveSupport::TimeZone["UTC"])
    assert_equal  86_399.999999998,  twz2 - twz1
  end

  def test_minus_with_datetime
    assert_equal  86_400.0,  ActiveSupport::TimeWithZone.new(Time.utc(2000, 1, 2), ActiveSupport::TimeZone["UTC"]) - DateTime.civil(2000, 1, 1)
  end

  def test_minus_with_datetime_precision
    assert_equal  86_399.999999999,  ActiveSupport::TimeWithZone.new(Time.utc(2000, 1, 1, 23, 59, 59, Rational(999999999, 1000)), ActiveSupport::TimeZone["UTC"]) - DateTime.civil(2000, 1, 1)
  end

  def test_minus_with_wrapped_datetime
    assert_equal  86_400.0,  ActiveSupport::TimeWithZone.new(DateTime.civil(2000, 1, 2), ActiveSupport::TimeZone["UTC"]) - Time.utc(2000, 1, 1)
    assert_equal  86_400.0,  ActiveSupport::TimeWithZone.new(DateTime.civil(2000, 1, 2), ActiveSupport::TimeZone["UTC"]) - DateTime.civil(2000, 1, 1)
  end

  def test_plus_and_minus_enforce_spring_dst_rules
    utc = Time.utc(2006, 4, 2, 6, 59, 59) # == Apr 2 2006 01:59:59 EST; i.e., 1 second before daylight savings start
    twz = ActiveSupport::TimeWithZone.new(utc, @time_zone)
    assert_equal Time.utc(2006, 4, 2, 1, 59, 59), twz.time
    assert_equal false, twz.dst?
    assert_equal "EST", twz.zone
    twz = twz + 1
    assert_equal Time.utc(2006, 4, 2, 3), twz.time # adding 1 sec springs forward to 3:00AM EDT
    assert_equal true, twz.dst?
    assert_equal "EDT", twz.zone
    twz = twz - 1 # subtracting 1 second takes goes back to 1:59:59AM EST
    assert_equal Time.utc(2006, 4, 2, 1, 59, 59), twz.time
    assert_equal false, twz.dst?
    assert_equal "EST", twz.zone
  end

  def test_plus_and_minus_enforce_fall_dst_rules
    utc = Time.utc(2006, 10, 29, 5, 59, 59) # == Oct 29 2006 01:59:59 EST; i.e., 1 second before daylight savings end
    twz = ActiveSupport::TimeWithZone.new(utc, @time_zone)
    assert_equal Time.utc(2006, 10, 29, 1, 59, 59), twz.time
    assert_equal true, twz.dst?
    assert_equal "EDT", twz.zone
    twz = twz + 1
    assert_equal Time.utc(2006, 10, 29, 1), twz.time # adding 1 sec falls back from 1:59:59 EDT to 1:00AM EST
    assert_equal false, twz.dst?
    assert_equal "EST", twz.zone
    twz = twz - 1
    assert_equal Time.utc(2006, 10, 29, 1, 59, 59), twz.time # subtracting 1 sec goes back to 1:59:59AM EDT
    assert_equal true, twz.dst?
    assert_equal "EDT", twz.zone
  end

  def test_to_a
    assert_equal [45, 30, 5, 1, 2, 2000, 2, 32, false, "HST"], ActiveSupport::TimeWithZone.new(Time.utc(2000, 2, 1, 15, 30, 45), ActiveSupport::TimeZone["Hawaii"]).to_a
  end

  def test_to_f
    result = ActiveSupport::TimeWithZone.new(Time.utc(2000, 1, 1), ActiveSupport::TimeZone["Hawaii"]).to_f
    assert_equal 946684800.0, result
    assert_kind_of Float, result
  end

  def test_to_i
    result = ActiveSupport::TimeWithZone.new(Time.utc(2000, 1, 1), ActiveSupport::TimeZone["Hawaii"]).to_i
    assert_equal 946684800, result
    assert_kind_of Integer, result
  end

  def test_to_i_with_wrapped_datetime
    datetime = DateTime.civil(2000, 1, 1, 0)
    twz = ActiveSupport::TimeWithZone.new(datetime, @time_zone)
    assert_equal 946684800, twz.to_i
  end

  def test_to_r
    result = ActiveSupport::TimeWithZone.new(Time.utc(2000, 1, 1), ActiveSupport::TimeZone["Hawaii"]).to_r
    assert_equal Rational(946684800, 1), result
    assert_kind_of Rational, result
  end

  def test_time_at
    time = ActiveSupport::TimeWithZone.new(Time.utc(2000, 1, 1), ActiveSupport::TimeZone["Hawaii"])
    assert_equal time, Time.at(time)
  end

  def test_to_time
    with_env_tz "US/Eastern" do
      assert_equal Time, @twz.to_time.class
      assert_equal Time.local(1999, 12, 31, 19), @twz.to_time
      assert_equal Time.local(1999, 12, 31, 19).utc_offset, @twz.to_time.utc_offset
    end
  end

  def test_to_date
    # 1 sec before midnight Jan 1 EST
    assert_equal Date.new(1999, 12, 31), ActiveSupport::TimeWithZone.new(Time.utc(2000, 1, 1, 4, 59, 59), ActiveSupport::TimeZone["Eastern Time (US & Canada)"]).to_date
    # midnight Jan 1 EST
    assert_equal Date.new(2000,  1,  1), ActiveSupport::TimeWithZone.new(Time.utc(2000, 1, 1, 5,  0,  0), ActiveSupport::TimeZone["Eastern Time (US & Canada)"]).to_date
    # 1 sec before midnight Jan 2 EST
    assert_equal Date.new(2000,  1,  1), ActiveSupport::TimeWithZone.new(Time.utc(2000, 1, 2, 4, 59, 59), ActiveSupport::TimeZone["Eastern Time (US & Canada)"]).to_date
    # midnight Jan 2 EST
    assert_equal Date.new(2000,  1,  2), ActiveSupport::TimeWithZone.new(Time.utc(2000, 1, 2, 5,  0,  0), ActiveSupport::TimeZone["Eastern Time (US & Canada)"]).to_date
  end

  def test_to_datetime
    assert_equal DateTime.civil(1999, 12, 31, 19, 0, 0, Rational(-18_000, 86_400)),  @twz.to_datetime
  end

  def test_acts_like_time
    assert @twz.acts_like_time?
    assert @twz.acts_like?(:time)
    assert ActiveSupport::TimeWithZone.new(DateTime.civil(2000), @time_zone).acts_like?(:time)
  end

  def test_acts_like_date
    assert_equal false, @twz.acts_like?(:date)
    assert_equal false, ActiveSupport::TimeWithZone.new(DateTime.civil(2000), @time_zone).acts_like?(:date)
  end

  def test_is_a
    assert_kind_of Time, @twz
    assert_kind_of Time, @twz
    assert_kind_of ActiveSupport::TimeWithZone, @twz
  end

  def test_class_name
    assert_equal "Time", ActiveSupport::TimeWithZone.name
  end

  def test_method_missing_with_time_return_value
    assert_instance_of ActiveSupport::TimeWithZone, @twz.months_since(1)
    assert_equal Time.utc(2000, 1, 31, 19, 0 , 0), @twz.months_since(1).time
  end

  def test_marshal_dump_and_load
    marshal_str = Marshal.dump(@twz)
    mtime = Marshal.load(marshal_str)
    assert_equal Time.utc(2000, 1, 1, 0), mtime.utc
    assert mtime.utc.utc?
    assert_equal ActiveSupport::TimeZone["Eastern Time (US & Canada)"], mtime.time_zone
    assert_equal Time.utc(1999, 12, 31, 19), mtime.time
    assert mtime.time.utc?
    assert_equal @twz.inspect, mtime.inspect
  end

  def test_marshal_dump_and_load_with_tzinfo_identifier
    twz = ActiveSupport::TimeWithZone.new(@utc, TZInfo::Timezone.get("America/New_York"))
    marshal_str = Marshal.dump(twz)
    mtime = Marshal.load(marshal_str)
    assert_equal Time.utc(2000, 1, 1, 0), mtime.utc
    assert mtime.utc.utc?
    assert_equal "America/New_York", mtime.time_zone.name
    assert_equal Time.utc(1999, 12, 31, 19), mtime.time
    assert mtime.time.utc?
    assert_equal @twz.inspect, mtime.inspect
  end

  def test_freeze
    @twz.freeze
    assert @twz.frozen?
  end

  def test_freeze_preloads_instance_variables
    @twz.freeze
    assert_nothing_raised do
      @twz.period
      @twz.time
    end
  end

  def test_method_missing_with_non_time_return_value
    time = @twz.time
    def time.foo; "bar"; end
    assert_equal "bar", @twz.foo
  end

  def test_date_part_value_methods
    twz = ActiveSupport::TimeWithZone.new(Time.utc(1999, 12, 31, 19, 18, 17, 500), @time_zone)
    assert_not_called(twz, :method_missing) do
      assert_equal 1999, twz.year
      assert_equal 12, twz.month
      assert_equal 31, twz.day
      assert_equal 14, twz.hour
      assert_equal 18, twz.min
      assert_equal 17, twz.sec
      assert_equal 500, twz.usec
      assert_equal 5, twz.wday
      assert_equal 365, twz.yday
    end
  end

  def test_usec_returns_0_when_datetime_is_wrapped
    twz = ActiveSupport::TimeWithZone.new(DateTime.civil(2000), @time_zone)
    assert_equal 0, twz.usec
  end

  def test_usec_returns_sec_fraction_when_datetime_is_wrapped
    twz = ActiveSupport::TimeWithZone.new(DateTime.civil(2000, 1, 1, 0, 0, Rational(1, 2)), @time_zone)
    assert_equal 500000, twz.usec
  end

  def test_nsec_returns_sec_fraction_when_datetime_is_wrapped
    twz = ActiveSupport::TimeWithZone.new(DateTime.civil(2000, 1, 1, 0, 0, Rational(1, 2)), @time_zone)
    assert_equal 500000000, twz.nsec
  end

  def test_utc_to_local_conversion_saves_period_in_instance_variable
    assert_nil @twz.instance_variable_get("@period")
    @twz.time
    assert_kind_of TZInfo::TimezonePeriod, @twz.instance_variable_get("@period")
  end

  def test_instance_created_with_local_time_returns_correct_utc_time
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(1999, 12, 31, 19))
    assert_equal Time.utc(2000), twz.utc
  end

  def test_instance_created_with_local_time_enforces_spring_dst_rules
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2006, 4, 2, 2)) # first second of DST
    assert_equal Time.utc(2006, 4, 2, 3), twz.time # springs forward to 3AM
    assert_equal true, twz.dst?
    assert_equal "EDT", twz.zone
  end

  def test_instance_created_with_local_time_enforces_fall_dst_rules
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2006, 10, 29, 1)) # 1AM can be either DST or non-DST; we'll pick DST
    assert_equal Time.utc(2006, 10, 29, 1), twz.time
    assert_equal true, twz.dst?
    assert_equal "EDT", twz.zone
  end

  def test_ruby_19_weekday_name_query_methods
    %w(sunday? monday? tuesday? wednesday? thursday? friday? saturday?).each do |name|
      assert_respond_to @twz, name
      assert_equal @twz.send(name), @twz.method(name).call
    end
  end

  def test_utc_to_local_conversion_with_far_future_datetime
    assert_equal [0, 0, 19, 31, 12, 2049], ActiveSupport::TimeWithZone.new(DateTime.civil(2050), @time_zone).to_a[0, 6]
  end

  def test_local_to_utc_conversion_with_far_future_datetime
    assert_equal DateTime.civil(2050).to_f, ActiveSupport::TimeWithZone.new(nil, @time_zone, DateTime.civil(2049, 12, 31, 19)).to_f
  end

  def test_change
    assert_equal "Fri, 31 Dec 1999 19:00:00 EST -05:00", @twz.inspect
    assert_equal "Mon, 31 Dec 2001 19:00:00 EST -05:00", @twz.change(year: 2001).inspect
    assert_equal "Wed, 31 Mar 1999 19:00:00 EST -05:00", @twz.change(month: 3).inspect
    assert_equal "Wed, 03 Mar 1999 19:00:00 EST -05:00", @twz.change(month: 2).inspect
    assert_equal "Wed, 15 Dec 1999 19:00:00 EST -05:00", @twz.change(day: 15).inspect
    assert_equal "Fri, 31 Dec 1999 06:00:00 EST -05:00", @twz.change(hour: 6).inspect
    assert_equal "Fri, 31 Dec 1999 19:15:00 EST -05:00", @twz.change(min: 15).inspect
    assert_equal "Fri, 31 Dec 1999 19:00:30 EST -05:00", @twz.change(sec: 30).inspect
  end

  def test_change_at_dst_boundary
    twz = ActiveSupport::TimeWithZone.new(Time.at(1319936400).getutc, ActiveSupport::TimeZone["Madrid"])
    assert_equal twz, twz.change(min: 0)
  end

  def test_round_at_dst_boundary
    twz = ActiveSupport::TimeWithZone.new(Time.at(1319936400).getutc, ActiveSupport::TimeZone["Madrid"])
    assert_equal twz, twz.round
  end

  def test_advance
    assert_equal "Fri, 31 Dec 1999 19:00:00 EST -05:00", @twz.inspect
    assert_equal "Mon, 31 Dec 2001 19:00:00 EST -05:00", @twz.advance(years: 2).inspect
    assert_equal "Fri, 31 Mar 2000 19:00:00 EST -05:00", @twz.advance(months: 3).inspect
    assert_equal "Tue, 04 Jan 2000 19:00:00 EST -05:00", @twz.advance(days: 4).inspect
    assert_equal "Sat, 01 Jan 2000 01:00:00 EST -05:00", @twz.advance(hours: 6).inspect
    assert_equal "Fri, 31 Dec 1999 19:15:00 EST -05:00", @twz.advance(minutes: 15).inspect
    assert_equal "Fri, 31 Dec 1999 19:00:30 EST -05:00", @twz.advance(seconds: 30).inspect
  end

  def test_beginning_of_year
    assert_equal "Fri, 31 Dec 1999 19:00:00 EST -05:00", @twz.inspect
    assert_equal "Fri, 01 Jan 1999 00:00:00 EST -05:00", @twz.beginning_of_year.inspect
  end

  def test_end_of_year
    assert_equal "Fri, 31 Dec 1999 19:00:00 EST -05:00", @twz.inspect
    assert_equal "Fri, 31 Dec 1999 23:59:59 EST -05:00", @twz.end_of_year.inspect
  end

  def test_beginning_of_month
    assert_equal "Fri, 31 Dec 1999 19:00:00 EST -05:00", @twz.inspect
    assert_equal "Wed, 01 Dec 1999 00:00:00 EST -05:00", @twz.beginning_of_month.inspect
  end

  def test_end_of_month
    assert_equal "Fri, 31 Dec 1999 19:00:00 EST -05:00", @twz.inspect
    assert_equal "Fri, 31 Dec 1999 23:59:59 EST -05:00", @twz.end_of_month.inspect
  end

  def test_beginning_of_day
    assert_equal "Fri, 31 Dec 1999 19:00:00 EST -05:00", @twz.inspect
    assert_equal "Fri, 31 Dec 1999 00:00:00 EST -05:00", @twz.beginning_of_day.inspect
  end

  def test_end_of_day
    assert_equal "Fri, 31 Dec 1999 19:00:00 EST -05:00", @twz.inspect
    assert_equal "Fri, 31 Dec 1999 23:59:59 EST -05:00", @twz.end_of_day.inspect
  end

  def test_beginning_of_hour
    utc = Time.utc(2000, 1, 1, 0, 30)
    twz = ActiveSupport::TimeWithZone.new(utc, @time_zone)
    assert_equal "Fri, 31 Dec 1999 19:30:00 EST -05:00", twz.inspect
    assert_equal "Fri, 31 Dec 1999 19:00:00 EST -05:00", twz.beginning_of_hour.inspect
  end

  def test_end_of_hour
    utc = Time.utc(2000, 1, 1, 0, 30)
    twz = ActiveSupport::TimeWithZone.new(utc, @time_zone)
    assert_equal "Fri, 31 Dec 1999 19:30:00 EST -05:00", twz.inspect
    assert_equal "Fri, 31 Dec 1999 19:59:59 EST -05:00", twz.end_of_hour.inspect
  end

  def test_beginning_of_minute
    utc = Time.utc(2000, 1, 1, 0, 30, 10)
    twz = ActiveSupport::TimeWithZone.new(utc, @time_zone)
    assert_equal "Fri, 31 Dec 1999 19:30:10 EST -05:00", twz.inspect
    assert_equal "Fri, 31 Dec 1999 19:00:00 EST -05:00", twz.beginning_of_hour.inspect
  end

  def test_end_of_minute
    utc = Time.utc(2000, 1, 1, 0, 30, 10)
    twz = ActiveSupport::TimeWithZone.new(utc, @time_zone)
    assert_equal "Fri, 31 Dec 1999 19:30:10 EST -05:00", twz.inspect
    assert_equal "Fri, 31 Dec 1999 19:30:59 EST -05:00", twz.end_of_minute.inspect
  end

  def test_since
    assert_equal "Fri, 31 Dec 1999 19:00:01 EST -05:00", @twz.since(1).inspect
  end

  def test_in
    assert_equal "Fri, 31 Dec 1999 19:00:01 EST -05:00", @twz.in(1).inspect
  end

  def test_ago
    assert_equal "Fri, 31 Dec 1999 18:59:59 EST -05:00", @twz.ago(1).inspect
  end

  def test_seconds_since_midnight
    assert_equal 19 * 60 * 60, @twz.seconds_since_midnight
  end

  def test_advance_1_year_from_leap_day
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2004, 2, 29))
    assert_equal "Mon, 28 Feb 2005 00:00:00 EST -05:00", twz.advance(years: 1).inspect
    assert_equal "Mon, 28 Feb 2005 00:00:00 EST -05:00", twz.years_since(1).inspect
    assert_equal "Mon, 28 Feb 2005 00:00:00 EST -05:00", twz.since(1.year).inspect
    assert_equal "Mon, 28 Feb 2005 00:00:00 EST -05:00", twz.in(1.year).inspect
    assert_equal "Mon, 28 Feb 2005 00:00:00 EST -05:00", (twz + 1.year).inspect
  end

  def test_advance_1_month_from_last_day_of_january
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2005, 1, 31))
    assert_equal "Mon, 28 Feb 2005 00:00:00 EST -05:00", twz.advance(months: 1).inspect
    assert_equal "Mon, 28 Feb 2005 00:00:00 EST -05:00", twz.months_since(1).inspect
    assert_equal "Mon, 28 Feb 2005 00:00:00 EST -05:00", twz.since(1.month).inspect
    assert_equal "Mon, 28 Feb 2005 00:00:00 EST -05:00", twz.in(1.month).inspect
    assert_equal "Mon, 28 Feb 2005 00:00:00 EST -05:00", (twz + 1.month).inspect
  end

  def test_advance_1_month_from_last_day_of_january_during_leap_year
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2000, 1, 31))
    assert_equal "Tue, 29 Feb 2000 00:00:00 EST -05:00", twz.advance(months: 1).inspect
    assert_equal "Tue, 29 Feb 2000 00:00:00 EST -05:00", twz.months_since(1).inspect
    assert_equal "Tue, 29 Feb 2000 00:00:00 EST -05:00", twz.since(1.month).inspect
    assert_equal "Tue, 29 Feb 2000 00:00:00 EST -05:00", twz.in(1.month).inspect
    assert_equal "Tue, 29 Feb 2000 00:00:00 EST -05:00", (twz + 1.month).inspect
  end

  def test_advance_1_month_into_spring_dst_gap
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2006, 3, 2, 2))
    assert_equal "Sun, 02 Apr 2006 03:00:00 EDT -04:00", twz.advance(months: 1).inspect
    assert_equal "Sun, 02 Apr 2006 03:00:00 EDT -04:00", twz.months_since(1).inspect
    assert_equal "Sun, 02 Apr 2006 03:00:00 EDT -04:00", twz.since(1.month).inspect
    assert_equal "Sun, 02 Apr 2006 03:00:00 EDT -04:00", twz.in(1.month).inspect
    assert_equal "Sun, 02 Apr 2006 03:00:00 EDT -04:00", (twz + 1.month).inspect
  end

  def test_advance_1_second_into_spring_dst_gap
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2006, 4, 2, 1, 59, 59))
    assert_equal "Sun, 02 Apr 2006 03:00:00 EDT -04:00", twz.advance(seconds: 1).inspect
    assert_equal "Sun, 02 Apr 2006 03:00:00 EDT -04:00", (twz + 1).inspect
    assert_equal "Sun, 02 Apr 2006 03:00:00 EDT -04:00", (twz + 1.second).inspect
    assert_equal "Sun, 02 Apr 2006 03:00:00 EDT -04:00", twz.since(1).inspect
    assert_equal "Sun, 02 Apr 2006 03:00:00 EDT -04:00", twz.since(1.second).inspect
    assert_equal "Sun, 02 Apr 2006 03:00:00 EDT -04:00", twz.in(1).inspect
    assert_equal "Sun, 02 Apr 2006 03:00:00 EDT -04:00", twz.in(1.second).inspect
  end

  def test_advance_1_day_across_spring_dst_transition
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2006, 4, 1, 10, 30))
    # In 2006, spring DST transition occurred Apr 2 at 2AM; this day was only 23 hours long
    # When we advance 1 day, we want to end up at the same time on the next day
    assert_equal "Sun, 02 Apr 2006 10:30:00 EDT -04:00", twz.advance(days: 1).inspect
    assert_equal "Sun, 02 Apr 2006 10:30:00 EDT -04:00", twz.since(1.days).inspect
    assert_equal "Sun, 02 Apr 2006 10:30:00 EDT -04:00", twz.in(1.days).inspect
    assert_equal "Sun, 02 Apr 2006 10:30:00 EDT -04:00", (twz + 1.days).inspect
    assert_equal "Sun, 02 Apr 2006 10:30:01 EDT -04:00", twz.since(1.days + 1.second).inspect
    assert_equal "Sun, 02 Apr 2006 10:30:01 EDT -04:00", twz.in(1.days + 1.second).inspect
    assert_equal "Sun, 02 Apr 2006 10:30:01 EDT -04:00", (twz + 1.days + 1.second).inspect
  end

  def test_advance_1_day_across_spring_dst_transition_backwards
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2006, 4, 2, 10, 30))
    # In 2006, spring DST transition occurred Apr 2 at 2AM; this day was only 23 hours long
    # When we advance back 1 day, we want to end up at the same time on the previous day
    assert_equal "Sat, 01 Apr 2006 10:30:00 EST -05:00", twz.advance(days: -1).inspect
    assert_equal "Sat, 01 Apr 2006 10:30:00 EST -05:00", twz.ago(1.days).inspect
    assert_equal "Sat, 01 Apr 2006 10:30:00 EST -05:00", (twz - 1.days).inspect
    assert_equal "Sat, 01 Apr 2006 10:30:01 EST -05:00", twz.ago(1.days - 1.second).inspect
  end

  def test_advance_1_day_expressed_as_number_of_seconds_minutes_or_hours_across_spring_dst_transition
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2006, 4, 1, 10, 30))
    # In 2006, spring DST transition occurred Apr 2 at 2AM; this day was only 23 hours long
    # When we advance a specific number of hours, minutes or seconds, we want to advance exactly that amount
    assert_equal "Sun, 02 Apr 2006 11:30:00 EDT -04:00", (twz + 86400).inspect
    assert_equal "Sun, 02 Apr 2006 11:30:00 EDT -04:00", (twz + 86400.seconds).inspect
    assert_equal "Sun, 02 Apr 2006 11:30:00 EDT -04:00", twz.since(86400).inspect
    assert_equal "Sun, 02 Apr 2006 11:30:00 EDT -04:00", twz.since(86400.seconds).inspect
    assert_equal "Sun, 02 Apr 2006 11:30:00 EDT -04:00", twz.in(86400).inspect
    assert_equal "Sun, 02 Apr 2006 11:30:00 EDT -04:00", twz.in(86400.seconds).inspect
    assert_equal "Sun, 02 Apr 2006 11:30:00 EDT -04:00", twz.advance(seconds: 86400).inspect
    assert_equal "Sun, 02 Apr 2006 11:30:00 EDT -04:00", (twz + 1440.minutes).inspect
    assert_equal "Sun, 02 Apr 2006 11:30:00 EDT -04:00", twz.since(1440.minutes).inspect
    assert_equal "Sun, 02 Apr 2006 11:30:00 EDT -04:00", twz.in(1440.minutes).inspect
    assert_equal "Sun, 02 Apr 2006 11:30:00 EDT -04:00", twz.advance(minutes: 1440).inspect
    assert_equal "Sun, 02 Apr 2006 11:30:00 EDT -04:00", (twz + 24.hours).inspect
    assert_equal "Sun, 02 Apr 2006 11:30:00 EDT -04:00", twz.since(24.hours).inspect
    assert_equal "Sun, 02 Apr 2006 11:30:00 EDT -04:00", twz.in(24.hours).inspect
    assert_equal "Sun, 02 Apr 2006 11:30:00 EDT -04:00", twz.advance(hours: 24).inspect
  end

  def test_advance_1_day_expressed_as_number_of_seconds_minutes_or_hours_across_spring_dst_transition_backwards
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2006, 4, 2, 11, 30))
    # In 2006, spring DST transition occurred Apr 2 at 2AM; this day was only 23 hours long
    # When we advance a specific number of hours, minutes or seconds, we want to advance exactly that amount
    assert_equal "Sat, 01 Apr 2006 10:30:00 EST -05:00", (twz - 86400).inspect
    assert_equal "Sat, 01 Apr 2006 10:30:00 EST -05:00", (twz - 86400.seconds).inspect
    assert_equal "Sat, 01 Apr 2006 10:30:00 EST -05:00", twz.ago(86400).inspect
    assert_equal "Sat, 01 Apr 2006 10:30:00 EST -05:00", twz.ago(86400.seconds).inspect
    assert_equal "Sat, 01 Apr 2006 10:30:00 EST -05:00", twz.advance(seconds: -86400).inspect
    assert_equal "Sat, 01 Apr 2006 10:30:00 EST -05:00", (twz - 1440.minutes).inspect
    assert_equal "Sat, 01 Apr 2006 10:30:00 EST -05:00", twz.ago(1440.minutes).inspect
    assert_equal "Sat, 01 Apr 2006 10:30:00 EST -05:00", twz.advance(minutes: -1440).inspect
    assert_equal "Sat, 01 Apr 2006 10:30:00 EST -05:00", (twz - 24.hours).inspect
    assert_equal "Sat, 01 Apr 2006 10:30:00 EST -05:00", twz.ago(24.hours).inspect
    assert_equal "Sat, 01 Apr 2006 10:30:00 EST -05:00", twz.advance(hours: -24).inspect
  end

  def test_advance_1_day_across_fall_dst_transition
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2006, 10, 28, 10, 30))
    # In 2006, fall DST transition occurred Oct 29 at 2AM; this day was 25 hours long
    # When we advance 1 day, we want to end up at the same time on the next day
    assert_equal "Sun, 29 Oct 2006 10:30:00 EST -05:00", twz.advance(days: 1).inspect
    assert_equal "Sun, 29 Oct 2006 10:30:00 EST -05:00", twz.since(1.days).inspect
    assert_equal "Sun, 29 Oct 2006 10:30:00 EST -05:00", twz.in(1.days).inspect
    assert_equal "Sun, 29 Oct 2006 10:30:00 EST -05:00", (twz + 1.days).inspect
    assert_equal "Sun, 29 Oct 2006 10:30:01 EST -05:00", twz.since(1.days + 1.second).inspect
    assert_equal "Sun, 29 Oct 2006 10:30:01 EST -05:00", twz.in(1.days + 1.second).inspect
    assert_equal "Sun, 29 Oct 2006 10:30:01 EST -05:00", (twz + 1.days + 1.second).inspect
  end

  def test_advance_1_day_across_fall_dst_transition_backwards
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2006, 10, 29, 10, 30))
    # In 2006, fall DST transition occurred Oct 29 at 2AM; this day was 25 hours long
    # When we advance backwards 1 day, we want to end up at the same time on the previous day
    assert_equal "Sat, 28 Oct 2006 10:30:00 EDT -04:00", twz.advance(days: -1).inspect
    assert_equal "Sat, 28 Oct 2006 10:30:00 EDT -04:00", twz.ago(1.days).inspect
    assert_equal "Sat, 28 Oct 2006 10:30:00 EDT -04:00", (twz - 1.days).inspect
    assert_equal "Sat, 28 Oct 2006 10:30:01 EDT -04:00", twz.ago(1.days - 1.second).inspect
  end

  def test_advance_1_day_expressed_as_number_of_seconds_minutes_or_hours_across_fall_dst_transition
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2006, 10, 28, 10, 30))
    # In 2006, fall DST transition occurred Oct 29 at 2AM; this day was 25 hours long
    # When we advance a specific number of hours, minutes or seconds, we want to advance exactly that amount
    assert_equal "Sun, 29 Oct 2006 09:30:00 EST -05:00", (twz + 86400).inspect
    assert_equal "Sun, 29 Oct 2006 09:30:00 EST -05:00", (twz + 86400.seconds).inspect
    assert_equal "Sun, 29 Oct 2006 09:30:00 EST -05:00", twz.since(86400).inspect
    assert_equal "Sun, 29 Oct 2006 09:30:00 EST -05:00", twz.since(86400.seconds).inspect
    assert_equal "Sun, 29 Oct 2006 09:30:00 EST -05:00", twz.in(86400).inspect
    assert_equal "Sun, 29 Oct 2006 09:30:00 EST -05:00", twz.in(86400.seconds).inspect
    assert_equal "Sun, 29 Oct 2006 09:30:00 EST -05:00", twz.advance(seconds: 86400).inspect
    assert_equal "Sun, 29 Oct 2006 09:30:00 EST -05:00", (twz + 1440.minutes).inspect
    assert_equal "Sun, 29 Oct 2006 09:30:00 EST -05:00", twz.since(1440.minutes).inspect
    assert_equal "Sun, 29 Oct 2006 09:30:00 EST -05:00", twz.in(1440.minutes).inspect
    assert_equal "Sun, 29 Oct 2006 09:30:00 EST -05:00", twz.advance(minutes: 1440).inspect
    assert_equal "Sun, 29 Oct 2006 09:30:00 EST -05:00", (twz + 24.hours).inspect
    assert_equal "Sun, 29 Oct 2006 09:30:00 EST -05:00", twz.since(24.hours).inspect
    assert_equal "Sun, 29 Oct 2006 09:30:00 EST -05:00", twz.in(24.hours).inspect
    assert_equal "Sun, 29 Oct 2006 09:30:00 EST -05:00", twz.advance(hours: 24).inspect
  end

  def test_advance_1_day_expressed_as_number_of_seconds_minutes_or_hours_across_fall_dst_transition_backwards
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2006, 10, 29, 9, 30))
    # In 2006, fall DST transition occurred Oct 29 at 2AM; this day was 25 hours long
    # When we advance a specific number of hours, minutes or seconds, we want to advance exactly that amount
    assert_equal "Sat, 28 Oct 2006 10:30:00 EDT -04:00", (twz - 86400).inspect
    assert_equal "Sat, 28 Oct 2006 10:30:00 EDT -04:00", (twz - 86400.seconds).inspect
    assert_equal "Sat, 28 Oct 2006 10:30:00 EDT -04:00", twz.ago(86400).inspect
    assert_equal "Sat, 28 Oct 2006 10:30:00 EDT -04:00", twz.ago(86400.seconds).inspect
    assert_equal "Sat, 28 Oct 2006 10:30:00 EDT -04:00", twz.advance(seconds: -86400).inspect
    assert_equal "Sat, 28 Oct 2006 10:30:00 EDT -04:00", (twz - 1440.minutes).inspect
    assert_equal "Sat, 28 Oct 2006 10:30:00 EDT -04:00", twz.ago(1440.minutes).inspect
    assert_equal "Sat, 28 Oct 2006 10:30:00 EDT -04:00", twz.advance(minutes: -1440).inspect
    assert_equal "Sat, 28 Oct 2006 10:30:00 EDT -04:00", (twz - 24.hours).inspect
    assert_equal "Sat, 28 Oct 2006 10:30:00 EDT -04:00", twz.ago(24.hours).inspect
    assert_equal "Sat, 28 Oct 2006 10:30:00 EDT -04:00", twz.advance(hours: -24).inspect
  end

  def test_advance_1_week_across_spring_dst_transition
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2006, 4, 1, 10, 30))
    assert_equal "Sat, 08 Apr 2006 10:30:00 EDT -04:00", twz.advance(weeks: 1).inspect
    assert_equal "Sat, 08 Apr 2006 10:30:00 EDT -04:00", twz.weeks_since(1).inspect
    assert_equal "Sat, 08 Apr 2006 10:30:00 EDT -04:00", twz.since(1.week).inspect
    assert_equal "Sat, 08 Apr 2006 10:30:00 EDT -04:00", twz.in(1.week).inspect
    assert_equal "Sat, 08 Apr 2006 10:30:00 EDT -04:00", (twz + 1.week).inspect
  end

  def test_advance_1_week_across_spring_dst_transition_backwards
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2006, 4, 8, 10, 30))
    assert_equal "Sat, 01 Apr 2006 10:30:00 EST -05:00", twz.advance(weeks: -1).inspect
    assert_equal "Sat, 01 Apr 2006 10:30:00 EST -05:00", twz.weeks_ago(1).inspect
    assert_equal "Sat, 01 Apr 2006 10:30:00 EST -05:00", twz.ago(1.week).inspect
    assert_equal "Sat, 01 Apr 2006 10:30:00 EST -05:00", (twz - 1.week).inspect
  end

  def test_advance_1_week_across_fall_dst_transition
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2006, 10, 28, 10, 30))
    assert_equal "Sat, 04 Nov 2006 10:30:00 EST -05:00", twz.advance(weeks: 1).inspect
    assert_equal "Sat, 04 Nov 2006 10:30:00 EST -05:00", twz.weeks_since(1).inspect
    assert_equal "Sat, 04 Nov 2006 10:30:00 EST -05:00", twz.since(1.week).inspect
    assert_equal "Sat, 04 Nov 2006 10:30:00 EST -05:00", twz.in(1.week).inspect
    assert_equal "Sat, 04 Nov 2006 10:30:00 EST -05:00", (twz + 1.week).inspect
  end

  def test_advance_1_week_across_fall_dst_transition_backwards
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2006, 11, 4, 10, 30))
    assert_equal "Sat, 28 Oct 2006 10:30:00 EDT -04:00", twz.advance(weeks: -1).inspect
    assert_equal "Sat, 28 Oct 2006 10:30:00 EDT -04:00", twz.weeks_ago(1).inspect
    assert_equal "Sat, 28 Oct 2006 10:30:00 EDT -04:00", twz.ago(1.week).inspect
    assert_equal "Sat, 28 Oct 2006 10:30:00 EDT -04:00", (twz - 1.week).inspect
  end

  def test_advance_1_month_across_spring_dst_transition
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2006, 4, 1, 10, 30))
    assert_equal "Mon, 01 May 2006 10:30:00 EDT -04:00", twz.advance(months: 1).inspect
    assert_equal "Mon, 01 May 2006 10:30:00 EDT -04:00", twz.months_since(1).inspect
    assert_equal "Mon, 01 May 2006 10:30:00 EDT -04:00", twz.since(1.month).inspect
    assert_equal "Mon, 01 May 2006 10:30:00 EDT -04:00", twz.in(1.month).inspect
    assert_equal "Mon, 01 May 2006 10:30:00 EDT -04:00", (twz + 1.month).inspect
  end

  def test_advance_1_month_across_spring_dst_transition_backwards
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2006, 5, 1, 10, 30))
    assert_equal "Sat, 01 Apr 2006 10:30:00 EST -05:00", twz.advance(months: -1).inspect
    assert_equal "Sat, 01 Apr 2006 10:30:00 EST -05:00", twz.months_ago(1).inspect
    assert_equal "Sat, 01 Apr 2006 10:30:00 EST -05:00", twz.ago(1.month).inspect
    assert_equal "Sat, 01 Apr 2006 10:30:00 EST -05:00", (twz - 1.month).inspect
  end

  def test_advance_1_month_across_fall_dst_transition
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2006, 10, 28, 10, 30))
    assert_equal "Tue, 28 Nov 2006 10:30:00 EST -05:00", twz.advance(months: 1).inspect
    assert_equal "Tue, 28 Nov 2006 10:30:00 EST -05:00", twz.months_since(1).inspect
    assert_equal "Tue, 28 Nov 2006 10:30:00 EST -05:00", twz.since(1.month).inspect
    assert_equal "Tue, 28 Nov 2006 10:30:00 EST -05:00", twz.in(1.month).inspect
    assert_equal "Tue, 28 Nov 2006 10:30:00 EST -05:00", (twz + 1.month).inspect
  end

  def test_advance_1_month_across_fall_dst_transition_backwards
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2006, 11, 28, 10, 30))
    assert_equal "Sat, 28 Oct 2006 10:30:00 EDT -04:00", twz.advance(months: -1).inspect
    assert_equal "Sat, 28 Oct 2006 10:30:00 EDT -04:00", twz.months_ago(1).inspect
    assert_equal "Sat, 28 Oct 2006 10:30:00 EDT -04:00", twz.ago(1.month).inspect
    assert_equal "Sat, 28 Oct 2006 10:30:00 EDT -04:00", (twz - 1.month).inspect
  end

  def test_advance_1_year
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2008, 2, 15, 10, 30))
    assert_equal "Sun, 15 Feb 2009 10:30:00 EST -05:00", twz.advance(years: 1).inspect
    assert_equal "Sun, 15 Feb 2009 10:30:00 EST -05:00", twz.years_since(1).inspect
    assert_equal "Sun, 15 Feb 2009 10:30:00 EST -05:00", twz.since(1.year).inspect
    assert_equal "Sun, 15 Feb 2009 10:30:00 EST -05:00", twz.in(1.year).inspect
    assert_equal "Sun, 15 Feb 2009 10:30:00 EST -05:00", (twz + 1.year).inspect
    assert_equal "Thu, 15 Feb 2007 10:30:00 EST -05:00", twz.advance(years: -1).inspect
    assert_equal "Thu, 15 Feb 2007 10:30:00 EST -05:00", twz.years_ago(1).inspect
    assert_equal "Thu, 15 Feb 2007 10:30:00 EST -05:00", (twz - 1.year).inspect
  end

  def test_advance_1_year_during_dst
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2008, 7, 15, 10, 30))
    assert_equal "Wed, 15 Jul 2009 10:30:00 EDT -04:00", twz.advance(years: 1).inspect
    assert_equal "Wed, 15 Jul 2009 10:30:00 EDT -04:00", twz.years_since(1).inspect
    assert_equal "Wed, 15 Jul 2009 10:30:00 EDT -04:00", twz.since(1.year).inspect
    assert_equal "Wed, 15 Jul 2009 10:30:00 EDT -04:00", twz.in(1.year).inspect
    assert_equal "Wed, 15 Jul 2009 10:30:00 EDT -04:00", (twz + 1.year).inspect
    assert_equal "Sun, 15 Jul 2007 10:30:00 EDT -04:00", twz.advance(years: -1).inspect
    assert_equal "Sun, 15 Jul 2007 10:30:00 EDT -04:00", twz.years_ago(1).inspect
    assert_equal "Sun, 15 Jul 2007 10:30:00 EDT -04:00", (twz - 1.year).inspect
  end

  def test_no_method_error_has_proper_context
    rubinius_skip "Error message inconsistency"

    e = assert_raises(NoMethodError) {
      @twz.this_method_does_not_exist
    }
    assert_equal "undefined method `this_method_does_not_exist' for Fri, 31 Dec 1999 19:00:00 EST -05:00:Time", e.message
    assert_no_match "rescue", e.backtrace.first
  end
end

class TimeWithZoneMethodsForTimeAndDateTimeTest < ActiveSupport::TestCase
  include TimeZoneTestHelpers

  def setup
    @t, @dt, @zone = Time.utc(2000), DateTime.civil(2000), Time.zone
  end

  def teardown
    Time.zone = @zone
  end

  def test_in_time_zone
    Time.use_zone "Alaska" do
      assert_equal "Fri, 31 Dec 1999 15:00:00 AKST -09:00", @t.in_time_zone.inspect
      assert_equal "Fri, 31 Dec 1999 15:00:00 AKST -09:00", @dt.in_time_zone.inspect
    end
    Time.use_zone "Hawaii" do
      assert_equal "Fri, 31 Dec 1999 14:00:00 HST -10:00", @t.in_time_zone.inspect
      assert_equal "Fri, 31 Dec 1999 14:00:00 HST -10:00", @dt.in_time_zone.inspect
    end
    Time.use_zone nil do
      assert_equal @t, @t.in_time_zone
      assert_equal @dt, @dt.in_time_zone
    end
  end

  def test_nil_time_zone
    Time.use_zone nil do
      assert !@t.in_time_zone.respond_to?(:period), "no period method"
      assert !@dt.in_time_zone.respond_to?(:period), "no period method"
    end
  end

  def test_in_time_zone_with_argument
    Time.use_zone "Eastern Time (US & Canada)" do # Time.zone will not affect #in_time_zone(zone)
      assert_equal "Fri, 31 Dec 1999 15:00:00 AKST -09:00", @t.in_time_zone("Alaska").inspect
      assert_equal "Fri, 31 Dec 1999 15:00:00 AKST -09:00", @dt.in_time_zone("Alaska").inspect
      assert_equal "Fri, 31 Dec 1999 14:00:00 HST -10:00", @t.in_time_zone("Hawaii").inspect
      assert_equal "Fri, 31 Dec 1999 14:00:00 HST -10:00", @dt.in_time_zone("Hawaii").inspect
      assert_equal "Sat, 01 Jan 2000 00:00:00 UTC +00:00", @t.in_time_zone("UTC").inspect
      assert_equal "Sat, 01 Jan 2000 00:00:00 UTC +00:00", @dt.in_time_zone("UTC").inspect
      assert_equal "Fri, 31 Dec 1999 15:00:00 AKST -09:00", @t.in_time_zone(-9.hours).inspect
    end
  end

  def test_in_time_zone_with_invalid_argument
    assert_raise(ArgumentError) {  @t.in_time_zone("No such timezone exists") }
    assert_raise(ArgumentError) { @dt.in_time_zone("No such timezone exists") }
    assert_raise(ArgumentError) {  @t.in_time_zone(-15.hours) }
    assert_raise(ArgumentError) { @dt.in_time_zone(-15.hours) }
    assert_raise(ArgumentError) {  @t.in_time_zone(Object.new) }
    assert_raise(ArgumentError) { @dt.in_time_zone(Object.new) }
  end

  def test_in_time_zone_with_time_local_instance
    with_env_tz "US/Eastern" do
      time = Time.local(1999, 12, 31, 19) # == Time.utc(2000)
      assert_equal "Fri, 31 Dec 1999 15:00:00 AKST -09:00", time.in_time_zone("Alaska").inspect
    end
  end

  def test_localtime
    Time.zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    assert_equal @dt.in_time_zone.localtime, @dt.in_time_zone.utc.to_time.getlocal
  end

  def test_use_zone
    Time.zone = "Alaska"
    Time.use_zone "Hawaii" do
      assert_equal ActiveSupport::TimeZone["Hawaii"], Time.zone
    end
    assert_equal ActiveSupport::TimeZone["Alaska"], Time.zone
  end

  def test_use_zone_with_exception_raised
    Time.zone = "Alaska"
    assert_raise RuntimeError do
      Time.use_zone("Hawaii") { raise RuntimeError }
    end
    assert_equal ActiveSupport::TimeZone["Alaska"], Time.zone
  end

  def test_use_zone_raises_on_invalid_timezone
    Time.zone = "Alaska"
    assert_raise ArgumentError do
      Time.use_zone("No such timezone exists") {}
    end
    assert_equal ActiveSupport::TimeZone["Alaska"], Time.zone
  end

  def test_time_zone_getter_and_setter
    Time.zone = ActiveSupport::TimeZone["Alaska"]
    assert_equal ActiveSupport::TimeZone["Alaska"], Time.zone
    Time.zone = "Alaska"
    assert_equal ActiveSupport::TimeZone["Alaska"], Time.zone
    Time.zone = -9.hours
    assert_equal ActiveSupport::TimeZone["Alaska"], Time.zone
    Time.zone = nil
    assert_equal nil, Time.zone
  end

  def test_time_zone_getter_and_setter_with_zone_default_set
    old_zone_default = Time.zone_default
    Time.zone_default = ActiveSupport::TimeZone["Alaska"]
    assert_equal ActiveSupport::TimeZone["Alaska"], Time.zone
    Time.zone = ActiveSupport::TimeZone["Hawaii"]
    assert_equal ActiveSupport::TimeZone["Hawaii"], Time.zone
    Time.zone = nil
    assert_equal ActiveSupport::TimeZone["Alaska"], Time.zone
  ensure
    Time.zone_default = old_zone_default
  end

  def test_time_zone_setter_is_thread_safe
    Time.use_zone "Paris" do
      t1 = Thread.new { Time.zone = "Alaska" }.join
      t2 = Thread.new { Time.zone = "Hawaii" }.join
      assert t1.stop?, "Thread 1 did not finish running"
      assert t2.stop?, "Thread 2 did not finish running"
      assert_equal ActiveSupport::TimeZone["Paris"], Time.zone
      assert_equal ActiveSupport::TimeZone["Alaska"], t1[:time_zone]
      assert_equal ActiveSupport::TimeZone["Hawaii"], t2[:time_zone]
    end
  end

  def test_time_zone_setter_with_tzinfo_timezone_object_wraps_in_rails_time_zone
    tzinfo = TZInfo::Timezone.get("America/New_York")
    Time.zone = tzinfo
    assert_kind_of ActiveSupport::TimeZone, Time.zone
    assert_equal tzinfo, Time.zone.tzinfo
    assert_equal "America/New_York", Time.zone.name
    assert_equal(-18_000, Time.zone.utc_offset)
  end

  def test_time_zone_setter_with_tzinfo_timezone_identifier_does_lookup_and_wraps_in_rails_time_zone
    Time.zone = "America/New_York"
    assert_kind_of ActiveSupport::TimeZone, Time.zone
    assert_equal "America/New_York", Time.zone.tzinfo.name
    assert_equal "America/New_York", Time.zone.name
    assert_equal(-18_000, Time.zone.utc_offset)
  end

  def test_time_zone_setter_with_invalid_zone
    assert_raise(ArgumentError) { Time.zone = "No such timezone exists" }
    assert_raise(ArgumentError) { Time.zone = -15.hours }
    assert_raise(ArgumentError) { Time.zone = Object.new }
  end

  def test_find_zone_without_bang_returns_nil_if_time_zone_can_not_be_found
    assert_nil Time.find_zone("No such timezone exists")
    assert_nil Time.find_zone(-15.hours)
    assert_nil Time.find_zone(Object.new)
  end

  def test_find_zone_with_bang_raises_if_time_zone_can_not_be_found
    assert_raise(ArgumentError) { Time.find_zone!("No such timezone exists") }
    assert_raise(ArgumentError) { Time.find_zone!(-15.hours) }
    assert_raise(ArgumentError) { Time.find_zone!(Object.new) }
  end

  def test_time_zone_setter_with_find_zone_without_bang
    assert_nil Time.zone = Time.find_zone("No such timezone exists")
    assert_nil Time.zone = Time.find_zone(-15.hours)
    assert_nil Time.zone = Time.find_zone(Object.new)
  end

  def test_current_returns_time_now_when_zone_not_set
    with_env_tz "US/Eastern" do
      Time.stub(:now, Time.local(2000)) do
        assert_equal false, Time.current.is_a?(ActiveSupport::TimeWithZone)
        assert_equal Time.local(2000), Time.current
      end
    end
  end

  def test_current_returns_time_zone_now_when_zone_set
    Time.zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    with_env_tz "US/Eastern" do
      Time.stub(:now, Time.local(2000)) do
        assert_equal true, Time.current.is_a?(ActiveSupport::TimeWithZone)
        assert_equal "Eastern Time (US & Canada)", Time.current.time_zone.name
        assert_equal Time.utc(2000), Time.current.time
      end
    end
  end

  def test_time_in_time_zone_doesnt_affect_receiver
    with_env_tz "Europe/London" do
      time = Time.local(2000, 7, 1)
      time_with_zone = time.in_time_zone("Eastern Time (US & Canada)")
      assert_equal Time.utc(2000, 6, 30, 23, 0, 0), time_with_zone
      assert_not time.utc?, "time expected to be local, but is UTC"
    end
  end
end

class TimeWithZoneMethodsForDate < ActiveSupport::TestCase
  include TimeZoneTestHelpers

  def setup
    @d = Date.civil(2000)
  end

  def test_in_time_zone
    with_tz_default "Alaska" do
      assert_equal "Sat, 01 Jan 2000 00:00:00 AKST -09:00", @d.in_time_zone.inspect
    end
    with_tz_default "Hawaii" do
      assert_equal "Sat, 01 Jan 2000 00:00:00 HST -10:00", @d.in_time_zone.inspect
    end
    with_tz_default nil do
      assert_equal @d.to_time, @d.in_time_zone
    end
  end

  def test_nil_time_zone
    with_tz_default nil do
      assert !@d.in_time_zone.respond_to?(:period), "no period method"
    end
  end

  def test_in_time_zone_with_argument
    with_tz_default "Eastern Time (US & Canada)" do # Time.zone will not affect #in_time_zone(zone)
      assert_equal "Sat, 01 Jan 2000 00:00:00 AKST -09:00", @d.in_time_zone("Alaska").inspect
      assert_equal "Sat, 01 Jan 2000 00:00:00 HST -10:00", @d.in_time_zone("Hawaii").inspect
      assert_equal "Sat, 01 Jan 2000 00:00:00 UTC +00:00", @d.in_time_zone("UTC").inspect
      assert_equal "Sat, 01 Jan 2000 00:00:00 AKST -09:00", @d.in_time_zone(-9.hours).inspect
    end
  end

  def test_in_time_zone_with_invalid_argument
    assert_raise(ArgumentError) { @d.in_time_zone("No such timezone exists") }
    assert_raise(ArgumentError) { @d.in_time_zone(-15.hours) }
    assert_raise(ArgumentError) { @d.in_time_zone(Object.new) }
  end
end

class TimeWithZoneMethodsForString < ActiveSupport::TestCase
  include TimeZoneTestHelpers

  def setup
    @s = "Sat, 01 Jan 2000 00:00:00"
    @u = "Sat, 01 Jan 2000 00:00:00 UTC +00:00"
    @z = "Fri, 31 Dec 1999 19:00:00 EST -05:00"
  end

  def test_in_time_zone
    with_tz_default "Alaska" do
      assert_equal "Sat, 01 Jan 2000 00:00:00 AKST -09:00", @s.in_time_zone.inspect
      assert_equal "Fri, 31 Dec 1999 15:00:00 AKST -09:00", @u.in_time_zone.inspect
      assert_equal "Fri, 31 Dec 1999 15:00:00 AKST -09:00", @z.in_time_zone.inspect
    end
    with_tz_default "Hawaii" do
      assert_equal "Sat, 01 Jan 2000 00:00:00 HST -10:00", @s.in_time_zone.inspect
      assert_equal "Fri, 31 Dec 1999 14:00:00 HST -10:00", @u.in_time_zone.inspect
      assert_equal "Fri, 31 Dec 1999 14:00:00 HST -10:00", @z.in_time_zone.inspect
    end
    with_tz_default nil do
      assert_equal @s.to_time, @s.in_time_zone
      assert_equal @u.to_time, @u.in_time_zone
      assert_equal @z.to_time, @z.in_time_zone
    end
  end

  def test_nil_time_zone
    with_tz_default nil do
      assert !@s.in_time_zone.respond_to?(:period), "no period method"
      assert !@u.in_time_zone.respond_to?(:period), "no period method"
      assert !@z.in_time_zone.respond_to?(:period), "no period method"
    end
  end

  def test_in_time_zone_with_argument
    with_tz_default "Eastern Time (US & Canada)" do # Time.zone will not affect #in_time_zone(zone)
      assert_equal "Sat, 01 Jan 2000 00:00:00 AKST -09:00", @s.in_time_zone("Alaska").inspect
      assert_equal "Fri, 31 Dec 1999 15:00:00 AKST -09:00", @u.in_time_zone("Alaska").inspect
      assert_equal "Fri, 31 Dec 1999 15:00:00 AKST -09:00", @z.in_time_zone("Alaska").inspect
      assert_equal "Sat, 01 Jan 2000 00:00:00 HST -10:00", @s.in_time_zone("Hawaii").inspect
      assert_equal "Fri, 31 Dec 1999 14:00:00 HST -10:00", @u.in_time_zone("Hawaii").inspect
      assert_equal "Fri, 31 Dec 1999 14:00:00 HST -10:00", @z.in_time_zone("Hawaii").inspect
      assert_equal "Sat, 01 Jan 2000 00:00:00 UTC +00:00", @s.in_time_zone("UTC").inspect
      assert_equal "Sat, 01 Jan 2000 00:00:00 UTC +00:00", @u.in_time_zone("UTC").inspect
      assert_equal "Sat, 01 Jan 2000 00:00:00 UTC +00:00", @z.in_time_zone("UTC").inspect
      assert_equal "Sat, 01 Jan 2000 00:00:00 AKST -09:00", @s.in_time_zone(-9.hours).inspect
      assert_equal "Fri, 31 Dec 1999 15:00:00 AKST -09:00", @u.in_time_zone(-9.hours).inspect
      assert_equal "Fri, 31 Dec 1999 15:00:00 AKST -09:00", @z.in_time_zone(-9.hours).inspect
    end
  end

  def test_in_time_zone_with_invalid_argument
    assert_raise(ArgumentError) { @s.in_time_zone("No such timezone exists") }
    assert_raise(ArgumentError) { @u.in_time_zone("No such timezone exists") }
    assert_raise(ArgumentError) { @z.in_time_zone("No such timezone exists") }
    assert_raise(ArgumentError) { @s.in_time_zone(-15.hours) }
    assert_raise(ArgumentError) { @u.in_time_zone(-15.hours) }
    assert_raise(ArgumentError) { @z.in_time_zone(-15.hours) }
    assert_raise(ArgumentError) { @s.in_time_zone(Object.new) }
    assert_raise(ArgumentError) { @u.in_time_zone(Object.new) }
    assert_raise(ArgumentError) { @z.in_time_zone(Object.new) }
  end
end
