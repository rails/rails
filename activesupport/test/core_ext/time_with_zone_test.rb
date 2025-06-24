# frozen_string_literal: true

require_relative "../abstract_unit"
require "active_support/time"
require_relative "../time_zone_test_helpers"
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

  def test_in_time_zone_with_ambiguous_time
    with_env_tz "Europe/Moscow" do
      assert_equal Time.utc(2014, 10, 25, 22, 0, 0), Time.local(2014, 10, 26, 1, 0, 0).in_time_zone("Moscow")
    end
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
    assert_equal "-04:00", ActiveSupport::TimeWithZone.new(Time.utc(2000, 6), @time_zone).formatted_offset # dst
  end

  def test_dst?
    assert_equal false, @twz.dst?
    assert_equal true, ActiveSupport::TimeWithZone.new(Time.utc(2000, 6), @time_zone).dst?
  end

  def test_zone
    assert_equal "EST", @twz.zone
    assert_equal "EDT", ActiveSupport::TimeWithZone.new(Time.utc(2000, 6), @time_zone).zone # dst
  end

  def test_nsec
    local     = Time.local(2011, 6, 7, 23, 59, 59, Rational(999999999, 1000))
    with_zone = ActiveSupport::TimeWithZone.new(nil, ActiveSupport::TimeZone["Hawaii"], local)

    assert_equal local.nsec, with_zone.nsec
    assert_equal 999999999, with_zone.nsec
  end

  def test_strftime
    assert_equal "1999-12-31 19:00:00 EST -0500", @twz.strftime("%Y-%m-%d %H:%M:%S %Z %z")
  end

  def test_strftime_with_escaping
    assert_equal "%Z %z", @twz.strftime("%%Z %%z")
    assert_equal "%EST %-0500", @twz.strftime("%%%Z %%%z")
  end

  def test_inspect
    assert_equal "1999-12-31 19:00:00.000000000 EST -05:00", @twz.inspect

    nsec          = Time.utc(1986, 12, 12, 6, 23, 00, Rational(1, 1000))
    nsec          = ActiveSupport::TimeWithZone.new(nsec, @time_zone)
    assert_equal "1986-12-12 01:23:00.000000001 EST -05:00", nsec.inspect

    hundred_nsec  = Time.utc(1986, 12, 12, 6, 23, 00, Rational(100, 1000))
    hundred_nsec  = ActiveSupport::TimeWithZone.new(hundred_nsec, @time_zone)
    assert_equal "1986-12-12 01:23:00.000000100 EST -05:00", hundred_nsec.inspect

    one_third_sec = Time.utc(1986, 12, 12, 6, 23, 00, Rational(1000000, 3))
    one_third_sec = ActiveSupport::TimeWithZone.new(one_third_sec, @time_zone)
    assert_equal "1986-12-12 01:23:00.333333333 EST -05:00", one_third_sec.inspect
  end

  def test_to_s
    assert_equal "1999-12-31 19:00:00 -0500", @twz.to_s
  end

  def test_to_fs
    assert_equal "1999-12-31 19:00:00 -0500", @twz.to_fs
  end

  def test_to_fs_db
    assert_equal "2000-01-01 00:00:00", @twz.to_fs(:db)
    assert_equal "2000-01-01 00:00:00", @twz.to_formatted_s(:db)
  end

  def test_to_fs_inspect
    assert_equal "1999-12-31 19:00:00.000000000 -0500", @twz.to_fs(:inspect)
  end

  def test_to_fs_not_existent
    assert_equal "1999-12-31 19:00:00 -0500", @twz.to_fs(:not_existent)
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

  def test_iso8601_with_fractional_seconds
    @twz += Rational(1, 8)
    assert_equal "1999-12-31T19:00:00.125-05:00", @twz.iso8601(3)
  end

  def test_rfc3339_with_fractional_seconds
    @twz += Rational(1, 8)
    assert_equal "1999-12-31T19:00:00.125-05:00", @twz.rfc3339(3)
  end

  def test_to_yaml
    yaml = <<~EOF
      --- !ruby/object:ActiveSupport::TimeWithZone
      utc: 2000-01-01 00:00:00.000000000 Z
      zone: !ruby/object:ActiveSupport::TimeZone
        name: America/New_York
      time: 1999-12-31 19:00:00.000000000 Z
    EOF

    # TODO: Remove assertion in Rails 7.1
    assert_not_deprecated(ActiveSupport.deprecator) do
      assert_equal(yaml, @twz.to_yaml)
    end
  end

  def test_ruby_to_yaml
    yaml = <<~EOF
      ---
      twz: !ruby/object:ActiveSupport::TimeWithZone
        utc: 2000-01-01 00:00:00.000000000 Z
        zone: !ruby/object:ActiveSupport::TimeZone
          name: America/New_York
        time: 1999-12-31 19:00:00.000000000 Z
    EOF

    # TODO: Remove assertion in Rails 7.1
    assert_not_deprecated(ActiveSupport.deprecator) do
      assert_equal(yaml, { "twz" => @twz }.to_yaml)
    end
  end

  def test_yaml_load
    yaml = <<~EOF
      --- !ruby/object:ActiveSupport::TimeWithZone
      utc: 2000-01-01 00:00:00.000000000 Z
      zone: !ruby/object:ActiveSupport::TimeZone
        name: America/New_York
      time: 1999-12-31 19:00:00.000000000 Z
    EOF

    loaded = YAML.respond_to?(:unsafe_load) ? YAML.unsafe_load(yaml) : YAML.load(yaml)
    assert_equal(@twz, loaded)
  end

  def test_ruby_yaml_load
    yaml = <<~EOF
      ---
      twz: !ruby/object:ActiveSupport::TimeWithZone
        utc: 2000-01-01 00:00:00.000000000 Z
        zone: !ruby/object:ActiveSupport::TimeZone
          name: America/New_York
        time: 1999-12-31 19:00:00.000000000 Z
    EOF

    loaded = YAML.respond_to?(:unsafe_load) ? YAML.unsafe_load(yaml) : YAML.load(yaml)
    assert_equal({ "twz" => @twz }, loaded)
  end

  def test_httpdate
    assert_equal "Sat, 01 Jan 2000 00:00:00 GMT", @twz.httpdate
  end

  def test_rfc2822
    assert_equal "Fri, 31 Dec 1999 19:00:00 -0500", @twz.rfc2822
  end

  def test_compare_with_time
    assert_equal 1, @twz <=> Time.utc(1999, 12, 31, 23, 59, 59)
    assert_equal 0, @twz <=> Time.utc(2000, 1, 1, 0, 0, 0)
    assert_equal(-1, @twz <=> Time.utc(2000, 1, 1, 0, 0, 1))
  end

  def test_compare_with_datetime
    assert_equal 1, @twz <=> DateTime.civil(1999, 12, 31, 23, 59, 59)
    assert_equal 0, @twz <=> DateTime.civil(2000, 1, 1, 0, 0, 0)
    assert_equal(-1, @twz <=> DateTime.civil(2000, 1, 1, 0, 0, 1))
  end

  def test_compare_with_time_with_zone
    assert_equal 1, @twz <=> ActiveSupport::TimeWithZone.new(Time.utc(1999, 12, 31, 23, 59, 59), ActiveSupport::TimeZone["UTC"])
    assert_equal 0, @twz <=> ActiveSupport::TimeWithZone.new(Time.utc(2000, 1, 1, 0, 0, 0), ActiveSupport::TimeZone["UTC"])
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

  def test_yesterday?
    Date.stub(:current, Date.new(2000, 1, 1)) do
      assert_equal true,  ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(1999, 12, 31, 23, 59, 59)).yesterday?
      assert_equal false, ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2000, 1, 1, 0)).yesterday?
      assert_equal true,  ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(1999, 12, 31)).yesterday?
      assert_equal false, ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2000, 1, 2, 0)).yesterday?
    end
  end

  def test_prev_day?
    Date.stub(:current, Date.new(2000, 1, 1)) do
      assert_equal true,  ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(1999, 12, 31, 23, 59, 59)).prev_day?
      assert_equal false, ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2000, 1, 1, 0)).prev_day?
      assert_equal true,  ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(1999, 12, 31)).prev_day?
      assert_equal false, ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2000, 1, 2, 0)).prev_day?
    end
  end

  def test_tomorrow?
    Date.stub(:current, Date.new(2000, 1, 1)) do
      assert_equal false, ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(1999, 12, 31, 23, 59, 59)).tomorrow?
      assert_equal true,  ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2000, 1, 2, 0)).tomorrow?
      assert_equal false, ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2000, 1, 1, 23, 59, 59)).tomorrow?
      assert_equal false, ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(1999, 12, 31, 0)).tomorrow?
    end
  end

  def test_next_day?
    Date.stub(:current, Date.new(2000, 1, 1)) do
      assert_equal false, ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(1999, 12, 31, 23, 59, 59)).next_day?
      assert_equal true,  ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2000, 1, 2, 0)).next_day?
      assert_equal false, ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2000, 1, 1, 23, 59, 59)).next_day?
      assert_equal false, ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(1999, 12, 31, 0)).next_day?
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

  def test_before
    twz = ActiveSupport::TimeWithZone.new(Time.utc(2017, 3, 6, 12, 0, 0), @time_zone)
    assert_equal false, twz.before?(ActiveSupport::TimeWithZone.new(Time.utc(2017, 3, 6, 11, 59, 59), @time_zone))
    assert_equal false, twz.before?(ActiveSupport::TimeWithZone.new(Time.utc(2017, 3, 6, 12, 0, 0), @time_zone))
    assert_equal true, twz.before?(ActiveSupport::TimeWithZone.new(Time.utc(2017, 3, 6, 12, 00, 1), @time_zone))
  end

  def test_after
    twz = ActiveSupport::TimeWithZone.new(Time.utc(2017, 3, 6, 12, 0, 0), @time_zone)
    assert_equal true, twz.after?(ActiveSupport::TimeWithZone.new(Time.utc(2017, 3, 6, 11, 59, 59), @time_zone))
    assert_equal false, twz.after?(ActiveSupport::TimeWithZone.new(Time.utc(2017, 3, 6, 12, 0, 0), @time_zone))
    assert_equal false, twz.after?(ActiveSupport::TimeWithZone.new(Time.utc(2017, 3, 6, 12, 00, 1), @time_zone))
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
    assert_equal Time.utc(1999, 12, 31, 19, 0, 5), (@twz + 5).time
  end

  def test_plus_with_integer_when_self_wraps_datetime
    datetime = DateTime.civil(2000, 1, 1, 0)
    twz = ActiveSupport::TimeWithZone.new(datetime, @time_zone)
    assert_equal DateTime.civil(1999, 12, 31, 19, 0, 5), (twz + 5).time
  end

  def test_no_limit_on_times
    twz = ActiveSupport::TimeWithZone.new(Time.utc(2000, 1, 1), @time_zone)
    assert_equal [0, 0, 19, 31, 12, 11999], (twz + 10_000.years).to_a[0, 6]
    assert_equal [0, 0, 19, 31, 12, -8001], (twz - 10_000.years).to_a[0, 6]
  end

  def test_plus_two_time_instances_raises_deprecation_warning
    twz = ActiveSupport::TimeWithZone.new(Time.utc(2000, 1, 1), @time_zone)
    assert_deprecated(ActiveSupport.deprecator) do
      twz + 10.days.ago
    end
  end

  def test_plus_with_invalid_argument
    twz = ActiveSupport::TimeWithZone.new(Time.utc(2000, 1, 1), @time_zone)
    assert_not_deprecated(ActiveSupport.deprecator) do
      assert_raises TypeError do
        twz + Object.new
      end
    end
  end

  def test_plus_with_duration
    assert_equal Time.utc(2000, 1, 5, 19, 0, 0), (@twz + 5.days).time
  end

  def test_minus_with_integer
    assert_equal Time.utc(1999, 12, 31, 18, 59, 55), (@twz - 5).time
  end

  def test_minus_with_integer_when_self_wraps_datetime
    datetime = DateTime.civil(2000, 1, 1, 0)
    twz = ActiveSupport::TimeWithZone.new(datetime, @time_zone)
    assert_equal DateTime.civil(1999, 12, 31, 18, 59, 55), (twz - 5).time
  end

  def test_minus_with_duration
    assert_equal Time.utc(1999, 12, 26, 19, 0, 0), (@twz - 5.days).time
  end

  def test_minus_with_time
    assert_equal 86_400.0,  ActiveSupport::TimeWithZone.new(Time.utc(2000, 1, 2), ActiveSupport::TimeZone["UTC"]) - Time.utc(2000, 1, 1)
    assert_equal 86_400.0,  ActiveSupport::TimeWithZone.new(Time.utc(2000, 1, 2), ActiveSupport::TimeZone["Hawaii"]) - Time.utc(2000, 1, 1)
  end

  def test_minus_with_time_precision
    assert_equal 86_399.999999998,  ActiveSupport::TimeWithZone.new(Time.utc(2000, 1, 2, 23, 59, 59, Rational(999999999, 1000)), ActiveSupport::TimeZone["UTC"]) - Time.utc(2000, 1, 2, 0, 0, 0, Rational(1, 1000))
    assert_equal 86_399.999999998,  ActiveSupport::TimeWithZone.new(Time.utc(2000, 1, 2, 23, 59, 59, Rational(999999999, 1000)), ActiveSupport::TimeZone["Hawaii"]) - Time.utc(2000, 1, 2, 0, 0, 0, Rational(1, 1000))
  end

  def test_minus_with_time_with_zone
    twz1 = ActiveSupport::TimeWithZone.new(Time.utc(2000, 1, 1), ActiveSupport::TimeZone["UTC"])
    twz2 = ActiveSupport::TimeWithZone.new(Time.utc(2000, 1, 2), ActiveSupport::TimeZone["UTC"])
    assert_equal 86_400.0,  twz2 - twz1
  end

  def test_minus_with_time_with_zone_without_preserve_configured
    with_preserve_timezone(nil) do
      twz1 = ActiveSupport::TimeWithZone.new(Time.utc(2000, 1, 1), ActiveSupport::TimeZone["UTC"])
      twz2 = ActiveSupport::TimeWithZone.new(Time.utc(2000, 1, 2), ActiveSupport::TimeZone["UTC"])

      difference = assert_not_deprecated(ActiveSupport.deprecator) { twz2 - twz1 }
      assert_equal 86_400.0, difference
    end
  end

  def test_minus_with_time_with_zone_precision
    twz1 = ActiveSupport::TimeWithZone.new(Time.utc(2000, 1, 1, 0, 0, 0, Rational(1, 1000)), ActiveSupport::TimeZone["UTC"])
    twz2 = ActiveSupport::TimeWithZone.new(Time.utc(2000, 1, 1, 23, 59, 59, Rational(999999999, 1000)), ActiveSupport::TimeZone["UTC"])
    assert_equal 86_399.999999998,  twz2 - twz1
  end

  def test_minus_with_datetime
    assert_equal 86_400.0,  ActiveSupport::TimeWithZone.new(Time.utc(2000, 1, 2), ActiveSupport::TimeZone["UTC"]) - DateTime.civil(2000, 1, 1)
  end

  def test_minus_with_datetime_precision
    assert_equal 86_399.999999999,  ActiveSupport::TimeWithZone.new(Time.utc(2000, 1, 1, 23, 59, 59, Rational(999999999, 1000)), ActiveSupport::TimeZone["UTC"]) - DateTime.civil(2000, 1, 1)
  end

  def test_minus_with_wrapped_datetime
    assert_equal 86_400.0,  ActiveSupport::TimeWithZone.new(DateTime.civil(2000, 1, 2), ActiveSupport::TimeZone["UTC"]) - Time.utc(2000, 1, 1)
    assert_equal 86_400.0,  ActiveSupport::TimeWithZone.new(DateTime.civil(2000, 1, 2), ActiveSupport::TimeZone["UTC"]) - DateTime.civil(2000, 1, 1)
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

  def test_to_time_with_preserve_timezone_using_zone
    with_preserve_timezone(:zone) do
      time = @twz.to_time
      local_time = with_env_tz("US/Eastern") { Time.local(1999, 12, 31, 19) }

      assert_equal Time, time.class
      assert_equal time.object_id, @twz.to_time.object_id
      assert_equal local_time, time
      assert_equal local_time.utc_offset, time.utc_offset
      assert_equal @time_zone, time.zone
    end
  end

  def test_to_time_with_preserve_timezone_using_offset
    with_preserve_timezone(:offset) do
      with_env_tz "US/Eastern" do
        time = @twz.to_time

        assert_equal Time, time.class
        assert_equal time.object_id, @twz.to_time.object_id
        assert_equal Time.local(1999, 12, 31, 19), time
        assert_equal Time.local(1999, 12, 31, 19).utc_offset, time.utc_offset
        assert_nil time.zone
      end
    end
  end

  def test_to_time_with_preserve_timezone_using_true
    with_preserve_timezone(true) do
      with_env_tz "US/Eastern" do
        time = @twz.to_time

        assert_equal Time, time.class
        assert_equal time.object_id, @twz.to_time.object_id
        assert_equal Time.local(1999, 12, 31, 19), time
        assert_equal Time.local(1999, 12, 31, 19).utc_offset, time.utc_offset
        assert_nil time.zone
      end
    end
  end

  def test_to_time_without_preserve_timezone
    with_preserve_timezone(false) do
      with_env_tz "US/Eastern" do
        time = @twz.to_time

        assert_equal Time, time.class
        assert_equal time.object_id, @twz.to_time.object_id
        assert_equal Time.local(1999, 12, 31, 19), time
        assert_equal Time.local(1999, 12, 31, 19).utc_offset, time.utc_offset
        assert_equal Time.local(1999, 12, 31, 19).zone, time.zone
      end
    end
  end

  def test_to_time_without_preserve_timezone_configured
    with_preserve_timezone(nil) do
      with_env_tz "US/Eastern" do
        time = assert_deprecated(ActiveSupport.deprecator) { @twz.to_time }

        assert_equal Time, time.class
        assert_equal time.object_id, @twz.to_time.object_id
        assert_equal Time.local(1999, 12, 31, 19), time
        assert_equal Time.local(1999, 12, 31, 19).utc_offset, time.utc_offset
        assert_equal Time.local(1999, 12, 31, 19).zone, time.zone

        assert_equal false, ActiveSupport.to_time_preserves_timezone
      end
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
    assert_predicate @twz, :acts_like_time?
    assert @twz.acts_like?(:time)
    assert ActiveSupport::TimeWithZone.new(DateTime.civil(2000), @time_zone).acts_like?(:time)
  end

  def test_acts_like_date
    assert_equal false, @twz.acts_like?(:date)
    assert_equal false, ActiveSupport::TimeWithZone.new(DateTime.civil(2000), @time_zone).acts_like?(:date)
  end

  def test_blank?
    assert_not_predicate @twz, :blank?
  end

  def test_is_a
    assert_kind_of Time, @twz
    assert_kind_of Time, @twz
    assert_kind_of ActiveSupport::TimeWithZone, @twz
  end

  def test_method_missing_with_time_return_value
    assert_instance_of ActiveSupport::TimeWithZone, @twz.months_since(1)
    assert_equal Time.utc(2000, 1, 31, 19, 0, 0), @twz.months_since(1).time
  end

  def test_marshal_dump_and_load
    marshal_str = Marshal.dump(@twz)
    mtime = Marshal.load(marshal_str)
    assert_equal Time.utc(2000, 1, 1, 0), mtime.utc
    assert_predicate mtime.utc, :utc?
    assert_equal ActiveSupport::TimeZone["Eastern Time (US & Canada)"], mtime.time_zone
    assert_equal Time.utc(1999, 12, 31, 19), mtime.time
    assert_predicate mtime.time, :utc?
    assert_equal @twz.inspect, mtime.inspect
  end

  def test_marshal_dump_and_load_with_tzinfo_identifier
    twz = ActiveSupport::TimeWithZone.new(@utc, TZInfo::Timezone.get("America/New_York"))
    marshal_str = Marshal.dump(twz)
    mtime = Marshal.load(marshal_str)
    assert_equal Time.utc(2000, 1, 1, 0), mtime.utc
    assert_predicate mtime.utc, :utc?
    assert_equal "America/New_York", mtime.time_zone.name
    assert_equal Time.utc(1999, 12, 31, 19), mtime.time
    assert_predicate mtime.time, :utc?
    assert_equal @twz.inspect, mtime.inspect
  end

  def test_freeze
    @twz.freeze
    assert_predicate @twz, :frozen?
  end

  def test_freeze_preloads_instance_variables
    @twz.freeze
    assert_nothing_raised do
      @twz.period
      @twz.time
      @twz.to_datetime
      @twz.to_time
    end
  end

  def test_method_missing_with_non_time_return_value
    time = @twz.time
    def time.foo; "bar"; end
    assert_equal "bar", @twz.foo
  end

  def test_method_missing_works_with_kwargs
    time = @twz.time
    def time.method_with_kwarg(foo:); foo; end
    assert_equal "bar", @twz.method_with_kwarg(foo: "bar")
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
      assert_equal @twz.public_send(name), @twz.method(name).call
    end
  end

  def test_utc_to_local_conversion_with_far_future_datetime
    assert_equal [0, 0, 19, 31, 12, 2049], ActiveSupport::TimeWithZone.new(DateTime.civil(2050), @time_zone).to_a[0, 6]
  end

  def test_local_to_utc_conversion_with_far_future_datetime
    assert_equal DateTime.civil(2050).to_f, ActiveSupport::TimeWithZone.new(nil, @time_zone, DateTime.civil(2049, 12, 31, 19)).to_f
  end

  def test_change
    assert_equal "1999-12-31 19:00:00.000000000 EST -05:00", @twz.inspect
    assert_equal "2001-12-31 19:00:00.000000000 EST -05:00", @twz.change(year: 2001).inspect
    assert_equal "1999-03-31 19:00:00.000000000 EST -05:00", @twz.change(month: 3).inspect
    assert_equal "1999-03-03 19:00:00.000000000 EST -05:00", @twz.change(month: 2).inspect
    assert_equal "1999-12-15 19:00:00.000000000 EST -05:00", @twz.change(day: 15).inspect
    assert_equal "1999-12-31 06:00:00.000000000 EST -05:00", @twz.change(hour: 6).inspect
    assert_equal "1999-12-31 19:15:00.000000000 EST -05:00", @twz.change(min: 15).inspect
    assert_equal "1999-12-31 19:00:30.000000000 EST -05:00", @twz.change(sec: 30).inspect
    assert_equal "1999-12-31 19:00:00.000000000 HST -10:00", @twz.change(offset: "-10:00").inspect
    assert_equal "1999-12-31 19:00:00.000000000 HST -10:00", @twz.change(offset: -36000).inspect
    assert_equal "1999-12-31 19:00:00.000000000 HST -10:00", @twz.change(zone: "Hawaii").inspect
    assert_equal "1999-12-31 19:00:00.000000000 HST -10:00", @twz.change(zone: -10).inspect
    assert_equal "1999-12-31 19:00:00.000000000 HST -10:00", @twz.change(zone: -36000).inspect
    assert_equal "1999-12-31 19:00:00.000000000 HST -10:00", @twz.change(zone: "Pacific/Honolulu").inspect
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
    assert_equal "1999-12-31 19:00:00.000000000 EST -05:00", @twz.inspect
    assert_equal "2001-12-31 19:00:00.000000000 EST -05:00", @twz.advance(years: 2).inspect
    assert_equal "2000-03-31 19:00:00.000000000 EST -05:00", @twz.advance(months: 3).inspect
    assert_equal "2000-01-04 19:00:00.000000000 EST -05:00", @twz.advance(days: 4).inspect
    assert_equal "2000-01-01 01:00:00.000000000 EST -05:00", @twz.advance(hours: 6).inspect
    assert_equal "1999-12-31 19:15:00.000000000 EST -05:00", @twz.advance(minutes: 15).inspect
    assert_equal "1999-12-31 19:00:30.000000000 EST -05:00", @twz.advance(seconds: 30).inspect
  end

  def test_beginning_of_year
    assert_equal "1999-12-31 19:00:00.000000000 EST -05:00", @twz.inspect
    assert_equal "1999-01-01 00:00:00.000000000 EST -05:00", @twz.beginning_of_year.inspect
  end

  def test_end_of_year
    assert_equal "1999-12-31 19:00:00.000000000 EST -05:00", @twz.inspect
    assert_equal "1999-12-31 23:59:59.999999999 EST -05:00", @twz.end_of_year.inspect
  end

  def test_beginning_of_month
    assert_equal "1999-12-31 19:00:00.000000000 EST -05:00", @twz.inspect
    assert_equal "1999-12-01 00:00:00.000000000 EST -05:00", @twz.beginning_of_month.inspect
  end

  def test_end_of_month
    assert_equal "1999-12-31 19:00:00.000000000 EST -05:00", @twz.inspect
    assert_equal "1999-12-31 23:59:59.999999999 EST -05:00", @twz.end_of_month.inspect
  end

  def test_beginning_of_day
    assert_equal "1999-12-31 19:00:00.000000000 EST -05:00", @twz.inspect
    assert_equal "1999-12-31 00:00:00.000000000 EST -05:00", @twz.beginning_of_day.inspect
  end

  def test_end_of_day
    assert_equal "1999-12-31 19:00:00.000000000 EST -05:00", @twz.inspect
    assert_equal "1999-12-31 23:59:59.999999999 EST -05:00", @twz.end_of_day.inspect
  end

  def test_beginning_of_hour
    utc = Time.utc(2000, 1, 1, 0, 30)
    twz = ActiveSupport::TimeWithZone.new(utc, @time_zone)
    assert_equal "1999-12-31 19:30:00.000000000 EST -05:00", twz.inspect
    assert_equal "1999-12-31 19:00:00.000000000 EST -05:00", twz.beginning_of_hour.inspect
  end

  def test_end_of_hour
    utc = Time.utc(2000, 1, 1, 0, 30)
    twz = ActiveSupport::TimeWithZone.new(utc, @time_zone)
    assert_equal "1999-12-31 19:30:00.000000000 EST -05:00", twz.inspect
    assert_equal "1999-12-31 19:59:59.999999999 EST -05:00", twz.end_of_hour.inspect
  end

  def test_beginning_of_minute
    utc = Time.utc(2000, 1, 1, 0, 30, 10)
    twz = ActiveSupport::TimeWithZone.new(utc, @time_zone)
    assert_equal "1999-12-31 19:30:10.000000000 EST -05:00", twz.inspect
    assert_equal "1999-12-31 19:00:00.000000000 EST -05:00", twz.beginning_of_hour.inspect
  end

  def test_end_of_minute
    utc = Time.utc(2000, 1, 1, 0, 30, 10)
    twz = ActiveSupport::TimeWithZone.new(utc, @time_zone)
    assert_equal "1999-12-31 19:30:10.000000000 EST -05:00", twz.inspect
    assert_equal "1999-12-31 19:30:59.999999999 EST -05:00", twz.end_of_minute.inspect
  end

  def test_since
    assert_equal "1999-12-31 19:00:01.000000000 EST -05:00", @twz.since(1).inspect
  end

  def test_in
    assert_equal "1999-12-31 19:00:01.000000000 EST -05:00", @twz.in(1).inspect
  end

  def test_ago
    assert_equal "1999-12-31 18:59:59.000000000 EST -05:00", @twz.ago(1).inspect
  end

  def test_seconds_since_midnight
    assert_equal 19 * 60 * 60, @twz.seconds_since_midnight
  end

  def test_advance_1_year_from_leap_day
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2004, 2, 29))
    assert_equal "2005-02-28 00:00:00.000000000 EST -05:00", twz.advance(years: 1).inspect
    assert_equal "2005-02-28 00:00:00.000000000 EST -05:00", twz.years_since(1).inspect
    assert_equal "2005-02-28 00:00:00.000000000 EST -05:00", twz.since(1.year).inspect
    assert_equal "2005-02-28 00:00:00.000000000 EST -05:00", twz.in(1.year).inspect
    assert_equal "2005-02-28 00:00:00.000000000 EST -05:00", (twz + 1.year).inspect
  end

  def test_advance_1_month_from_last_day_of_january
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2005, 1, 31))
    assert_equal "2005-02-28 00:00:00.000000000 EST -05:00", twz.advance(months: 1).inspect
    assert_equal "2005-02-28 00:00:00.000000000 EST -05:00", twz.months_since(1).inspect
    assert_equal "2005-02-28 00:00:00.000000000 EST -05:00", twz.since(1.month).inspect
    assert_equal "2005-02-28 00:00:00.000000000 EST -05:00", twz.in(1.month).inspect
    assert_equal "2005-02-28 00:00:00.000000000 EST -05:00", (twz + 1.month).inspect
  end

  def test_advance_1_month_from_last_day_of_january_during_leap_year
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2000, 1, 31))
    assert_equal "2000-02-29 00:00:00.000000000 EST -05:00", twz.advance(months: 1).inspect
    assert_equal "2000-02-29 00:00:00.000000000 EST -05:00", twz.months_since(1).inspect
    assert_equal "2000-02-29 00:00:00.000000000 EST -05:00", twz.since(1.month).inspect
    assert_equal "2000-02-29 00:00:00.000000000 EST -05:00", twz.in(1.month).inspect
    assert_equal "2000-02-29 00:00:00.000000000 EST -05:00", (twz + 1.month).inspect
  end

  def test_advance_1_month_into_spring_dst_gap
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2006, 3, 2, 2))
    assert_equal "2006-04-02 03:00:00.000000000 EDT -04:00", twz.advance(months: 1).inspect
    assert_equal "2006-04-02 03:00:00.000000000 EDT -04:00", twz.months_since(1).inspect
    assert_equal "2006-04-02 03:00:00.000000000 EDT -04:00", twz.since(1.month).inspect
    assert_equal "2006-04-02 03:00:00.000000000 EDT -04:00", twz.in(1.month).inspect
    assert_equal "2006-04-02 03:00:00.000000000 EDT -04:00", (twz + 1.month).inspect
  end

  def test_advance_1_second_into_spring_dst_gap
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2006, 4, 2, 1, 59, 59))
    assert_equal "2006-04-02 03:00:00.000000000 EDT -04:00", twz.advance(seconds: 1).inspect
    assert_equal "2006-04-02 03:00:00.000000000 EDT -04:00", (twz + 1).inspect
    assert_equal "2006-04-02 03:00:00.000000000 EDT -04:00", (twz + 1.second).inspect
    assert_equal "2006-04-02 03:00:00.000000000 EDT -04:00", twz.since(1).inspect
    assert_equal "2006-04-02 03:00:00.000000000 EDT -04:00", twz.since(1.second).inspect
    assert_equal "2006-04-02 03:00:00.000000000 EDT -04:00", twz.in(1).inspect
    assert_equal "2006-04-02 03:00:00.000000000 EDT -04:00", twz.in(1.second).inspect
  end

  def test_advance_1_day_across_spring_dst_transition
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2006, 4, 1, 10, 30))
    # In 2006, spring DST transition occurred Apr 2 at 2AM; this day was only 23 hours long
    # When we advance 1 day, we want to end up at the same time on the next day
    assert_equal "2006-04-02 10:30:00.000000000 EDT -04:00", twz.advance(days: 1).inspect
    assert_equal "2006-04-02 10:30:00.000000000 EDT -04:00", twz.since(1.days).inspect
    assert_equal "2006-04-02 10:30:00.000000000 EDT -04:00", twz.in(1.days).inspect
    assert_equal "2006-04-02 10:30:00.000000000 EDT -04:00", (twz + 1.days).inspect
    assert_equal "2006-04-02 10:30:01.000000000 EDT -04:00", twz.since(1.days + 1.second).inspect
    assert_equal "2006-04-02 10:30:01.000000000 EDT -04:00", twz.in(1.days + 1.second).inspect
    assert_equal "2006-04-02 10:30:01.000000000 EDT -04:00", (twz + 1.days + 1.second).inspect
  end

  def test_advance_1_day_across_spring_dst_transition_backwards
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2006, 4, 2, 10, 30))
    # In 2006, spring DST transition occurred Apr 2 at 2AM; this day was only 23 hours long
    # When we advance back 1 day, we want to end up at the same time on the previous day
    assert_equal "2006-04-01 10:30:00.000000000 EST -05:00", twz.advance(days: -1).inspect
    assert_equal "2006-04-01 10:30:00.000000000 EST -05:00", twz.ago(1.days).inspect
    assert_equal "2006-04-01 10:30:00.000000000 EST -05:00", (twz - 1.days).inspect
    assert_equal "2006-04-01 10:30:01.000000000 EST -05:00", twz.ago(1.days - 1.second).inspect
  end

  def test_advance_1_day_expressed_as_number_of_seconds_minutes_or_hours_across_spring_dst_transition
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2006, 4, 1, 10, 30))
    # In 2006, spring DST transition occurred Apr 2 at 2AM; this day was only 23 hours long
    # When we advance a specific number of hours, minutes or seconds, we want to advance exactly that amount
    assert_equal "2006-04-02 11:30:00.000000000 EDT -04:00", (twz + 86400).inspect
    assert_equal "2006-04-02 11:30:00.000000000 EDT -04:00", (twz + 86400.seconds).inspect
    assert_equal "2006-04-02 11:30:00.000000000 EDT -04:00", twz.since(86400).inspect
    assert_equal "2006-04-02 11:30:00.000000000 EDT -04:00", twz.since(86400.seconds).inspect
    assert_equal "2006-04-02 11:30:00.000000000 EDT -04:00", twz.in(86400).inspect
    assert_equal "2006-04-02 11:30:00.000000000 EDT -04:00", twz.in(86400.seconds).inspect
    assert_equal "2006-04-02 11:30:00.000000000 EDT -04:00", twz.advance(seconds: 86400).inspect
    assert_equal "2006-04-02 11:30:00.000000000 EDT -04:00", (twz + 1440.minutes).inspect
    assert_equal "2006-04-02 11:30:00.000000000 EDT -04:00", twz.since(1440.minutes).inspect
    assert_equal "2006-04-02 11:30:00.000000000 EDT -04:00", twz.in(1440.minutes).inspect
    assert_equal "2006-04-02 11:30:00.000000000 EDT -04:00", twz.advance(minutes: 1440).inspect
    assert_equal "2006-04-02 11:30:00.000000000 EDT -04:00", (twz + 24.hours).inspect
    assert_equal "2006-04-02 11:30:00.000000000 EDT -04:00", twz.since(24.hours).inspect
    assert_equal "2006-04-02 11:30:00.000000000 EDT -04:00", twz.in(24.hours).inspect
    assert_equal "2006-04-02 11:30:00.000000000 EDT -04:00", twz.advance(hours: 24).inspect
  end

  def test_advance_1_day_expressed_as_number_of_seconds_minutes_or_hours_across_spring_dst_transition_backwards
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2006, 4, 2, 11, 30))
    # In 2006, spring DST transition occurred Apr 2 at 2AM; this day was only 23 hours long
    # When we advance a specific number of hours, minutes or seconds, we want to advance exactly that amount
    assert_equal "2006-04-01 10:30:00.000000000 EST -05:00", (twz - 86400).inspect
    assert_equal "2006-04-01 10:30:00.000000000 EST -05:00", (twz - 86400.seconds).inspect
    assert_equal "2006-04-01 10:30:00.000000000 EST -05:00", twz.ago(86400).inspect
    assert_equal "2006-04-01 10:30:00.000000000 EST -05:00", twz.ago(86400.seconds).inspect
    assert_equal "2006-04-01 10:30:00.000000000 EST -05:00", twz.advance(seconds: -86400).inspect
    assert_equal "2006-04-01 10:30:00.000000000 EST -05:00", (twz - 1440.minutes).inspect
    assert_equal "2006-04-01 10:30:00.000000000 EST -05:00", twz.ago(1440.minutes).inspect
    assert_equal "2006-04-01 10:30:00.000000000 EST -05:00", twz.advance(minutes: -1440).inspect
    assert_equal "2006-04-01 10:30:00.000000000 EST -05:00", (twz - 24.hours).inspect
    assert_equal "2006-04-01 10:30:00.000000000 EST -05:00", twz.ago(24.hours).inspect
    assert_equal "2006-04-01 10:30:00.000000000 EST -05:00", twz.advance(hours: -24).inspect
  end

  def test_advance_1_day_across_fall_dst_transition
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2006, 10, 28, 10, 30))
    # In 2006, fall DST transition occurred Oct 29 at 2AM; this day was 25 hours long
    # When we advance 1 day, we want to end up at the same time on the next day
    assert_equal "2006-10-29 10:30:00.000000000 EST -05:00", twz.advance(days: 1).inspect
    assert_equal "2006-10-29 10:30:00.000000000 EST -05:00", twz.since(1.days).inspect
    assert_equal "2006-10-29 10:30:00.000000000 EST -05:00", twz.in(1.days).inspect
    assert_equal "2006-10-29 10:30:00.000000000 EST -05:00", (twz + 1.days).inspect
    assert_equal "2006-10-29 10:30:01.000000000 EST -05:00", twz.since(1.days + 1.second).inspect
    assert_equal "2006-10-29 10:30:01.000000000 EST -05:00", twz.in(1.days + 1.second).inspect
    assert_equal "2006-10-29 10:30:01.000000000 EST -05:00", (twz + 1.days + 1.second).inspect
  end

  def test_advance_1_day_across_fall_dst_transition_backwards
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2006, 10, 29, 10, 30))
    # In 2006, fall DST transition occurred Oct 29 at 2AM; this day was 25 hours long
    # When we advance backwards 1 day, we want to end up at the same time on the previous day
    assert_equal "2006-10-28 10:30:00.000000000 EDT -04:00", twz.advance(days: -1).inspect
    assert_equal "2006-10-28 10:30:00.000000000 EDT -04:00", twz.ago(1.days).inspect
    assert_equal "2006-10-28 10:30:00.000000000 EDT -04:00", (twz - 1.days).inspect
    assert_equal "2006-10-28 10:30:01.000000000 EDT -04:00", twz.ago(1.days - 1.second).inspect
  end

  def test_advance_1_day_expressed_as_number_of_seconds_minutes_or_hours_across_fall_dst_transition
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2006, 10, 28, 10, 30))
    # In 2006, fall DST transition occurred Oct 29 at 2AM; this day was 25 hours long
    # When we advance a specific number of hours, minutes or seconds, we want to advance exactly that amount
    assert_equal "2006-10-29 09:30:00.000000000 EST -05:00", (twz + 86400).inspect
    assert_equal "2006-10-29 09:30:00.000000000 EST -05:00", (twz + 86400.seconds).inspect
    assert_equal "2006-10-29 09:30:00.000000000 EST -05:00", twz.since(86400).inspect
    assert_equal "2006-10-29 09:30:00.000000000 EST -05:00", twz.since(86400.seconds).inspect
    assert_equal "2006-10-29 09:30:00.000000000 EST -05:00", twz.in(86400).inspect
    assert_equal "2006-10-29 09:30:00.000000000 EST -05:00", twz.in(86400.seconds).inspect
    assert_equal "2006-10-29 09:30:00.000000000 EST -05:00", twz.advance(seconds: 86400).inspect
    assert_equal "2006-10-29 09:30:00.000000000 EST -05:00", (twz + 1440.minutes).inspect
    assert_equal "2006-10-29 09:30:00.000000000 EST -05:00", twz.since(1440.minutes).inspect
    assert_equal "2006-10-29 09:30:00.000000000 EST -05:00", twz.in(1440.minutes).inspect
    assert_equal "2006-10-29 09:30:00.000000000 EST -05:00", twz.advance(minutes: 1440).inspect
    assert_equal "2006-10-29 09:30:00.000000000 EST -05:00", (twz + 24.hours).inspect
    assert_equal "2006-10-29 09:30:00.000000000 EST -05:00", twz.since(24.hours).inspect
    assert_equal "2006-10-29 09:30:00.000000000 EST -05:00", twz.in(24.hours).inspect
    assert_equal "2006-10-29 09:30:00.000000000 EST -05:00", twz.advance(hours: 24).inspect
  end

  def test_advance_1_day_expressed_as_number_of_seconds_minutes_or_hours_across_fall_dst_transition_backwards
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2006, 10, 29, 9, 30))
    # In 2006, fall DST transition occurred Oct 29 at 2AM; this day was 25 hours long
    # When we advance a specific number of hours, minutes or seconds, we want to advance exactly that amount
    assert_equal "2006-10-28 10:30:00.000000000 EDT -04:00", (twz - 86400).inspect
    assert_equal "2006-10-28 10:30:00.000000000 EDT -04:00", (twz - 86400.seconds).inspect
    assert_equal "2006-10-28 10:30:00.000000000 EDT -04:00", twz.ago(86400).inspect
    assert_equal "2006-10-28 10:30:00.000000000 EDT -04:00", twz.ago(86400.seconds).inspect
    assert_equal "2006-10-28 10:30:00.000000000 EDT -04:00", twz.advance(seconds: -86400).inspect
    assert_equal "2006-10-28 10:30:00.000000000 EDT -04:00", (twz - 1440.minutes).inspect
    assert_equal "2006-10-28 10:30:00.000000000 EDT -04:00", twz.ago(1440.minutes).inspect
    assert_equal "2006-10-28 10:30:00.000000000 EDT -04:00", twz.advance(minutes: -1440).inspect
    assert_equal "2006-10-28 10:30:00.000000000 EDT -04:00", (twz - 24.hours).inspect
    assert_equal "2006-10-28 10:30:00.000000000 EDT -04:00", twz.ago(24.hours).inspect
    assert_equal "2006-10-28 10:30:00.000000000 EDT -04:00", twz.advance(hours: -24).inspect
  end

  def test_advance_1_week_across_spring_dst_transition
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2006, 4, 1, 10, 30))
    assert_equal "2006-04-08 10:30:00.000000000 EDT -04:00", twz.advance(weeks: 1).inspect
    assert_equal "2006-04-08 10:30:00.000000000 EDT -04:00", twz.weeks_since(1).inspect
    assert_equal "2006-04-08 10:30:00.000000000 EDT -04:00", twz.since(1.week).inspect
    assert_equal "2006-04-08 10:30:00.000000000 EDT -04:00", twz.in(1.week).inspect
    assert_equal "2006-04-08 10:30:00.000000000 EDT -04:00", (twz + 1.week).inspect
  end

  def test_advance_1_week_across_spring_dst_transition_backwards
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2006, 4, 8, 10, 30))
    assert_equal "2006-04-01 10:30:00.000000000 EST -05:00", twz.advance(weeks: -1).inspect
    assert_equal "2006-04-01 10:30:00.000000000 EST -05:00", twz.weeks_ago(1).inspect
    assert_equal "2006-04-01 10:30:00.000000000 EST -05:00", twz.ago(1.week).inspect
    assert_equal "2006-04-01 10:30:00.000000000 EST -05:00", (twz - 1.week).inspect
  end

  def test_advance_1_week_across_fall_dst_transition
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2006, 10, 28, 10, 30))
    assert_equal "2006-11-04 10:30:00.000000000 EST -05:00", twz.advance(weeks: 1).inspect
    assert_equal "2006-11-04 10:30:00.000000000 EST -05:00", twz.weeks_since(1).inspect
    assert_equal "2006-11-04 10:30:00.000000000 EST -05:00", twz.since(1.week).inspect
    assert_equal "2006-11-04 10:30:00.000000000 EST -05:00", twz.in(1.week).inspect
    assert_equal "2006-11-04 10:30:00.000000000 EST -05:00", (twz + 1.week).inspect
  end

  def test_advance_1_week_across_fall_dst_transition_backwards
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2006, 11, 4, 10, 30))
    assert_equal "2006-10-28 10:30:00.000000000 EDT -04:00", twz.advance(weeks: -1).inspect
    assert_equal "2006-10-28 10:30:00.000000000 EDT -04:00", twz.weeks_ago(1).inspect
    assert_equal "2006-10-28 10:30:00.000000000 EDT -04:00", twz.ago(1.week).inspect
    assert_equal "2006-10-28 10:30:00.000000000 EDT -04:00", (twz - 1.week).inspect
  end

  def test_advance_1_month_across_spring_dst_transition
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2006, 4, 1, 10, 30))
    assert_equal "2006-05-01 10:30:00.000000000 EDT -04:00", twz.advance(months: 1).inspect
    assert_equal "2006-05-01 10:30:00.000000000 EDT -04:00", twz.months_since(1).inspect
    assert_equal "2006-05-01 10:30:00.000000000 EDT -04:00", twz.since(1.month).inspect
    assert_equal "2006-05-01 10:30:00.000000000 EDT -04:00", twz.in(1.month).inspect
    assert_equal "2006-05-01 10:30:00.000000000 EDT -04:00", (twz + 1.month).inspect
  end

  def test_advance_1_month_across_spring_dst_transition_backwards
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2006, 5, 1, 10, 30))
    assert_equal "2006-04-01 10:30:00.000000000 EST -05:00", twz.advance(months: -1).inspect
    assert_equal "2006-04-01 10:30:00.000000000 EST -05:00", twz.months_ago(1).inspect
    assert_equal "2006-04-01 10:30:00.000000000 EST -05:00", twz.ago(1.month).inspect
    assert_equal "2006-04-01 10:30:00.000000000 EST -05:00", (twz - 1.month).inspect
  end

  def test_advance_1_month_across_fall_dst_transition
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2006, 10, 28, 10, 30))
    assert_equal "2006-11-28 10:30:00.000000000 EST -05:00", twz.advance(months: 1).inspect
    assert_equal "2006-11-28 10:30:00.000000000 EST -05:00", twz.months_since(1).inspect
    assert_equal "2006-11-28 10:30:00.000000000 EST -05:00", twz.since(1.month).inspect
    assert_equal "2006-11-28 10:30:00.000000000 EST -05:00", twz.in(1.month).inspect
    assert_equal "2006-11-28 10:30:00.000000000 EST -05:00", (twz + 1.month).inspect
  end

  def test_advance_1_month_across_fall_dst_transition_backwards
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2006, 11, 28, 10, 30))
    assert_equal "2006-10-28 10:30:00.000000000 EDT -04:00", twz.advance(months: -1).inspect
    assert_equal "2006-10-28 10:30:00.000000000 EDT -04:00", twz.months_ago(1).inspect
    assert_equal "2006-10-28 10:30:00.000000000 EDT -04:00", twz.ago(1.month).inspect
    assert_equal "2006-10-28 10:30:00.000000000 EDT -04:00", (twz - 1.month).inspect
  end

  def test_advance_1_year
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2008, 2, 15, 10, 30))
    assert_equal "2009-02-15 10:30:00.000000000 EST -05:00", twz.advance(years: 1).inspect
    assert_equal "2009-02-15 10:30:00.000000000 EST -05:00", twz.years_since(1).inspect
    assert_equal "2009-02-15 10:30:00.000000000 EST -05:00", twz.since(1.year).inspect
    assert_equal "2009-02-15 10:30:00.000000000 EST -05:00", twz.in(1.year).inspect
    assert_equal "2009-02-15 10:30:00.000000000 EST -05:00", (twz + 1.year).inspect
    assert_equal "2007-02-15 10:30:00.000000000 EST -05:00", twz.advance(years: -1).inspect
    assert_equal "2007-02-15 10:30:00.000000000 EST -05:00", twz.years_ago(1).inspect
    assert_equal "2007-02-15 10:30:00.000000000 EST -05:00", (twz - 1.year).inspect
  end

  def test_advance_1_year_during_dst
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2008, 7, 15, 10, 30))
    assert_equal "2009-07-15 10:30:00.000000000 EDT -04:00", twz.advance(years: 1).inspect
    assert_equal "2009-07-15 10:30:00.000000000 EDT -04:00", twz.years_since(1).inspect
    assert_equal "2009-07-15 10:30:00.000000000 EDT -04:00", twz.since(1.year).inspect
    assert_equal "2009-07-15 10:30:00.000000000 EDT -04:00", twz.in(1.year).inspect
    assert_equal "2009-07-15 10:30:00.000000000 EDT -04:00", (twz + 1.year).inspect
    assert_equal "2007-07-15 10:30:00.000000000 EDT -04:00", twz.advance(years: -1).inspect
    assert_equal "2007-07-15 10:30:00.000000000 EDT -04:00", twz.years_ago(1).inspect
    assert_equal "2007-07-15 10:30:00.000000000 EDT -04:00", (twz - 1.year).inspect
  end

  def test_no_method_error_has_proper_context
    e = assert_raises(NoMethodError) {
      @twz.this_method_does_not_exist
    }
    assert_match(/undefined method [`']this_method_does_not_exist' for.*ActiveSupport::TimeWithZone/, e.message)
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
      assert_equal "1999-12-31 15:00:00.000000000 AKST -09:00", @t.in_time_zone.inspect
      assert_equal "1999-12-31 15:00:00.000000000 AKST -09:00", @dt.in_time_zone.inspect
    end
    Time.use_zone "Hawaii" do
      assert_equal "1999-12-31 14:00:00.000000000 HST -10:00", @t.in_time_zone.inspect
      assert_equal "1999-12-31 14:00:00.000000000 HST -10:00", @dt.in_time_zone.inspect
    end
    Time.use_zone nil do
      assert_equal @t, @t.in_time_zone
      assert_equal @dt, @dt.in_time_zone
    end
  end

  def test_nil_time_zone
    Time.use_zone nil do
      assert_not_respond_to @t.in_time_zone, :period, "no period method"
      assert_not_respond_to @dt.in_time_zone, :period, "no period method"
    end
  end

  def test_in_time_zone_with_argument
    Time.use_zone "Eastern Time (US & Canada)" do # Time.zone will not affect #in_time_zone(zone)
      assert_equal "1999-12-31 15:00:00.000000000 AKST -09:00", @t.in_time_zone("Alaska").inspect
      assert_equal "1999-12-31 15:00:00.000000000 AKST -09:00", @dt.in_time_zone("Alaska").inspect
      assert_equal "1999-12-31 14:00:00.000000000 HST -10:00", @t.in_time_zone("Hawaii").inspect
      assert_equal "1999-12-31 14:00:00.000000000 HST -10:00", @dt.in_time_zone("Hawaii").inspect
      assert_equal "2000-01-01 00:00:00.000000000 UTC +00:00", @t.in_time_zone("UTC").inspect
      assert_equal "2000-01-01 00:00:00.000000000 UTC +00:00", @dt.in_time_zone("UTC").inspect
      assert_equal "1999-12-31 15:00:00.000000000 AKST -09:00", @t.in_time_zone(-9.hours).inspect
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
      assert_equal "1999-12-31 15:00:00.000000000 AKST -09:00", time.in_time_zone("Alaska").inspect
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
      Time.use_zone("No such timezone exists") { }
    end
    assert_equal ActiveSupport::TimeZone["Alaska"], Time.zone
  end

  def test_time_at_precision
    Time.use_zone "UTC" do
      time = "2019-01-01 00:00:00Z".to_time.end_of_month
      assert_equal Time.at(time), Time.at(time.in_time_zone)
    end
  end

  def test_time_zone_getter_and_setter
    Time.zone = ActiveSupport::TimeZone["Alaska"]
    assert_equal ActiveSupport::TimeZone["Alaska"], Time.zone
    Time.zone = "Alaska"
    assert_equal ActiveSupport::TimeZone["Alaska"], Time.zone
    Time.zone = -9.hours
    assert_equal ActiveSupport::TimeZone["Alaska"], Time.zone
    Time.zone = nil
    assert_nil Time.zone
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
      t1 = Thread.new { Time.zone = "Alaska"; Time.zone }
      t2 = Thread.new { Time.zone = "Hawaii"; Time.zone }
      assert_equal ActiveSupport::TimeZone["Paris"], Time.zone
      assert_equal ActiveSupport::TimeZone["Alaska"], t1.value
      assert_equal ActiveSupport::TimeZone["Hawaii"], t2.value
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
    error = assert_raise(ArgumentError) { Time.find_zone!("No such timezone exists") }
    assert_equal "Invalid Timezone: No such timezone exists", error.message

    error = assert_raise(ArgumentError) { Time.find_zone!(-15.hours) }
    assert_equal "Invalid Timezone: -54000", error.message

    error = assert_raise(ArgumentError) { Time.find_zone!(Object.new) }
    assert_match "invalid argument to TimeZone[]", error.message
  end

  def test_find_zone_with_bang_doesnt_raises_with_nil_and_false
    assert_nil Time.find_zone!(nil)
    assert_equal false, Time.find_zone!(false)
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
      assert_equal "2000-01-01 00:00:00.000000000 AKST -09:00", @d.in_time_zone.inspect
    end
    with_tz_default "Hawaii" do
      assert_equal "2000-01-01 00:00:00.000000000 HST -10:00", @d.in_time_zone.inspect
    end
    with_tz_default nil do
      assert_equal @d.to_time, @d.in_time_zone
    end
  end

  def test_nil_time_zone
    with_tz_default nil do
      assert_not_respond_to @d.in_time_zone, :period, "no period method"
    end
  end

  def test_in_time_zone_with_argument
    with_tz_default "Eastern Time (US & Canada)" do # Time.zone will not affect #in_time_zone(zone)
      assert_equal "2000-01-01 00:00:00.000000000 AKST -09:00", @d.in_time_zone("Alaska").inspect
      assert_equal "2000-01-01 00:00:00.000000000 HST -10:00", @d.in_time_zone("Hawaii").inspect
      assert_equal "2000-01-01 00:00:00.000000000 UTC +00:00", @d.in_time_zone("UTC").inspect
      assert_equal "2000-01-01 00:00:00.000000000 AKST -09:00", @d.in_time_zone(-9.hours).inspect
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
      assert_equal "2000-01-01 00:00:00.000000000 AKST -09:00", @s.in_time_zone.inspect
      assert_equal "1999-12-31 15:00:00.000000000 AKST -09:00", @u.in_time_zone.inspect
      assert_equal "1999-12-31 15:00:00.000000000 AKST -09:00", @z.in_time_zone.inspect
    end
    with_tz_default "Hawaii" do
      assert_equal "2000-01-01 00:00:00.000000000 HST -10:00", @s.in_time_zone.inspect
      assert_equal "1999-12-31 14:00:00.000000000 HST -10:00", @u.in_time_zone.inspect
      assert_equal "1999-12-31 14:00:00.000000000 HST -10:00", @z.in_time_zone.inspect
    end
    with_tz_default nil do
      assert_equal @s.to_time, @s.in_time_zone
      assert_equal @u.to_time, @u.in_time_zone
      assert_equal @z.to_time, @z.in_time_zone
    end
  end

  def test_nil_time_zone
    with_tz_default nil do
      assert_not_respond_to @s.in_time_zone, :period, "no period method"
      assert_not_respond_to @u.in_time_zone, :period, "no period method"
      assert_not_respond_to @z.in_time_zone, :period, "no period method"
    end
  end

  def test_in_time_zone_with_argument
    with_tz_default "Eastern Time (US & Canada)" do # Time.zone will not affect #in_time_zone(zone)
      assert_equal "2000-01-01 00:00:00.000000000 AKST -09:00", @s.in_time_zone("Alaska").inspect
      assert_equal "1999-12-31 15:00:00.000000000 AKST -09:00", @u.in_time_zone("Alaska").inspect
      assert_equal "1999-12-31 15:00:00.000000000 AKST -09:00", @z.in_time_zone("Alaska").inspect
      assert_equal "2000-01-01 00:00:00.000000000 HST -10:00", @s.in_time_zone("Hawaii").inspect
      assert_equal "1999-12-31 14:00:00.000000000 HST -10:00", @u.in_time_zone("Hawaii").inspect
      assert_equal "1999-12-31 14:00:00.000000000 HST -10:00", @z.in_time_zone("Hawaii").inspect
      assert_equal "2000-01-01 00:00:00.000000000 UTC +00:00", @s.in_time_zone("UTC").inspect
      assert_equal "2000-01-01 00:00:00.000000000 UTC +00:00", @u.in_time_zone("UTC").inspect
      assert_equal "2000-01-01 00:00:00.000000000 UTC +00:00", @z.in_time_zone("UTC").inspect
      assert_equal "2000-01-01 00:00:00.000000000 AKST -09:00", @s.in_time_zone(-9.hours).inspect
      assert_equal "1999-12-31 15:00:00.000000000 AKST -09:00", @u.in_time_zone(-9.hours).inspect
      assert_equal "1999-12-31 15:00:00.000000000 AKST -09:00", @z.in_time_zone(-9.hours).inspect
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

  def test_in_time_zone_with_ambiguous_time
    with_tz_default "Moscow" do
      assert_equal Time.utc(2014, 10, 25, 22, 0, 0), "2014-10-26 01:00:00".in_time_zone
    end
  end
end
