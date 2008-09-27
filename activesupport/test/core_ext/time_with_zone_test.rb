require 'abstract_unit'

class TimeWithZoneTest < Test::Unit::TestCase

  def setup
    @utc = Time.utc(2000, 1, 1, 0)
    @time_zone = ActiveSupport::TimeZone['Eastern Time (US & Canada)']
    @twz = ActiveSupport::TimeWithZone.new(@utc, @time_zone)
  end

  def test_utc
    assert_equal @utc, @twz.utc
  end

  def test_time
    silence_warnings do # silence warnings raised by tzinfo gem
      assert_equal Time.utc(1999, 12, 31, 19), @twz.time
    end
  end

  def test_time_zone
    assert_equal @time_zone, @twz.time_zone
  end

  def test_in_time_zone
    Time.use_zone 'Alaska' do
      assert_equal ActiveSupport::TimeWithZone.new(@utc, ActiveSupport::TimeZone['Alaska']), @twz.in_time_zone
    end
  end

  def test_in_time_zone_with_argument
    assert_equal ActiveSupport::TimeWithZone.new(@utc, ActiveSupport::TimeZone['Alaska']), @twz.in_time_zone('Alaska')
  end

  def test_in_time_zone_with_new_zone_equal_to_old_zone_does_not_create_new_object
    assert_equal @twz.object_id, @twz.in_time_zone(ActiveSupport::TimeZone['Eastern Time (US & Canada)']).object_id
  end

  def test_utc?
    assert_equal false, @twz.utc?
    assert_equal true, ActiveSupport::TimeWithZone.new(Time.utc(2000), ActiveSupport::TimeZone['UTC']).utc?
  end

  def test_formatted_offset
    silence_warnings do # silence warnings raised by tzinfo gem
      assert_equal '-05:00', @twz.formatted_offset
      assert_equal '-04:00', ActiveSupport::TimeWithZone.new(Time.utc(2000, 6), @time_zone).formatted_offset #dst
    end
  end

  def test_dst?
    silence_warnings do # silence warnings raised by tzinfo gem
      assert_equal false, @twz.dst?
      assert_equal true, ActiveSupport::TimeWithZone.new(Time.utc(2000, 6), @time_zone).dst?
    end
  end

  def test_zone
    silence_warnings do # silence warnings raised by tzinfo gem
      assert_equal 'EST', @twz.zone
      assert_equal 'EDT', ActiveSupport::TimeWithZone.new(Time.utc(2000, 6), @time_zone).zone #dst
    end
  end

  def test_to_json
    silence_warnings do # silence warnings raised by tzinfo gem
      assert_equal "\"1999/12/31 19:00:00 -0500\"", @twz.to_json
    end
  end

  def test_to_json_with_use_standard_json_time_format_config_set_to_true
    old, ActiveSupport.use_standard_json_time_format = ActiveSupport.use_standard_json_time_format, true
    assert_equal "\"1999-12-31T19:00:00-05:00\"", @twz.to_json
  ensure
    ActiveSupport.use_standard_json_time_format = old
  end

  def test_strftime
    silence_warnings do # silence warnings raised by tzinfo gem
      assert_equal '1999-12-31 19:00:00 EST -0500', @twz.strftime('%Y-%m-%d %H:%M:%S %Z %z')
    end
  end

  def test_inspect
    silence_warnings do # silence warnings raised by tzinfo gem
      assert_equal 'Fri, 31 Dec 1999 19:00:00 EST -05:00', @twz.inspect
    end
  end

  def test_to_s
    silence_warnings do # silence warnings raised by tzinfo gem
      assert_equal '1999-12-31 19:00:00 -0500', @twz.to_s
    end
  end

  def test_to_s_db
    silence_warnings do # silence warnings raised by tzinfo gem
      assert_equal '2000-01-01 00:00:00', @twz.to_s(:db)
    end
  end

  def test_xmlschema
    silence_warnings do # silence warnings raised by tzinfo gem
      assert_equal "1999-12-31T19:00:00-05:00", @twz.xmlschema
    end
  end

  def test_to_yaml
    silence_warnings do # silence warnings raised by tzinfo gem
      assert_equal "--- 1999-12-31 19:00:00 -05:00\n", @twz.to_yaml
    end
  end

  def test_ruby_to_yaml
    silence_warnings do
      assert_equal "--- \n:twz: 2000-01-01 00:00:00 Z\n", {:twz => @twz}.to_yaml
    end
  end

  def test_httpdate
    silence_warnings do # silence warnings raised by tzinfo gem
      assert_equal 'Sat, 01 Jan 2000 00:00:00 GMT', @twz.httpdate
    end
  end

  def test_rfc2822
    silence_warnings do # silence warnings raised by tzinfo gem
      assert_equal "Fri, 31 Dec 1999 19:00:00 -0500", @twz.rfc2822
    end
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
    assert_equal  1, @twz <=> ActiveSupport::TimeWithZone.new( Time.utc(1999, 12, 31, 23, 59, 59), ActiveSupport::TimeZone['UTC'] )
    assert_equal  0, @twz <=> ActiveSupport::TimeWithZone.new( Time.utc(2000, 1, 1, 0, 0, 0), ActiveSupport::TimeZone['UTC'] )
    assert_equal(-1, @twz <=> ActiveSupport::TimeWithZone.new( Time.utc(2000, 1, 1, 0, 0, 1), ActiveSupport::TimeZone['UTC'] ))
  end

  def test_between?
    assert @twz.between?(Time.utc(1999,12,31,23,59,59), Time.utc(2000,1,1,0,0,1))
    assert_equal false, @twz.between?(Time.utc(2000,1,1,0,0,1), Time.utc(2000,1,1,0,0,2))
  end

  uses_mocha 'TimeWithZone past?, today? and future?' do    
    def test_today
      Date.stubs(:current).returns(Date.new(2000, 1, 1))
      assert_equal false, ActiveSupport::TimeWithZone.new( nil, @time_zone, Time.utc(1999,12,31,23,59,59) ).today?
      assert_equal true,  ActiveSupport::TimeWithZone.new( nil, @time_zone, Time.utc(2000,1,1,0) ).today?
      assert_equal true,  ActiveSupport::TimeWithZone.new( nil, @time_zone, Time.utc(2000,1,1,23,59,59) ).today?
      assert_equal false, ActiveSupport::TimeWithZone.new( nil, @time_zone, Time.utc(2000,1,2,0) ).today?
    end
    
    def test_past_with_time_current_as_time_local
      with_env_tz 'US/Eastern' do
        Time.stubs(:current).returns(Time.local(2005,2,10,15,30,45))
        assert_equal true,  ActiveSupport::TimeWithZone.new( nil, @time_zone, Time.local(2005,2,10,15,30,44)).past?
        assert_equal false,  ActiveSupport::TimeWithZone.new( nil, @time_zone, Time.local(2005,2,10,15,30,45)).past?
        assert_equal false,  ActiveSupport::TimeWithZone.new( nil, @time_zone, Time.local(2005,2,10,15,30,46)).past?
      end
    end
    
    def test_past_with_time_current_as_time_with_zone
      twz = ActiveSupport::TimeWithZone.new( nil, @time_zone, Time.local(2005,2,10,15,30,45) )
      Time.stubs(:current).returns(twz)
      assert_equal true,  ActiveSupport::TimeWithZone.new( nil, @time_zone, Time.local(2005,2,10,15,30,44)).past?
      assert_equal false,  ActiveSupport::TimeWithZone.new( nil, @time_zone, Time.local(2005,2,10,15,30,45)).past?
      assert_equal false,  ActiveSupport::TimeWithZone.new( nil, @time_zone, Time.local(2005,2,10,15,30,46)).past?
    end
    
    def test_future_with_time_current_as_time_local
      with_env_tz 'US/Eastern' do
        Time.stubs(:current).returns(Time.local(2005,2,10,15,30,45))
        assert_equal false,  ActiveSupport::TimeWithZone.new( nil, @time_zone, Time.local(2005,2,10,15,30,44)).future?
        assert_equal false,  ActiveSupport::TimeWithZone.new( nil, @time_zone, Time.local(2005,2,10,15,30,45)).future?
        assert_equal true,  ActiveSupport::TimeWithZone.new( nil, @time_zone, Time.local(2005,2,10,15,30,46)).future?
      end
    end
    
    def future_with_time_current_as_time_with_zone
      twz = ActiveSupport::TimeWithZone.new( nil, @time_zone, Time.local(2005,2,10,15,30,45) )
      Time.stubs(:current).returns(twz)
      assert_equal false,  ActiveSupport::TimeWithZone.new( nil, @time_zone, Time.local(2005,2,10,15,30,44)).future?
      assert_equal false,  ActiveSupport::TimeWithZone.new( nil, @time_zone, Time.local(2005,2,10,15,30,45)).future?
      assert_equal true,  ActiveSupport::TimeWithZone.new( nil, @time_zone, Time.local(2005,2,10,15,30,46)).future?
    end
  end

  def test_eql?
    assert @twz.eql?(Time.utc(2000))
    assert @twz.eql?( ActiveSupport::TimeWithZone.new(Time.utc(2000), ActiveSupport::TimeZone["Hawaii"]) )
  end

  def test_plus_with_integer
    silence_warnings do # silence warnings raised by tzinfo gem
      assert_equal Time.utc(1999, 12, 31, 19, 0 ,5), (@twz + 5).time
    end
  end

  def test_plus_with_integer_when_self_wraps_datetime
    silence_warnings do # silence warnings raised by tzinfo gem
      datetime = DateTime.civil(2000, 1, 1, 0)
      twz = ActiveSupport::TimeWithZone.new(datetime, @time_zone)
      assert_equal DateTime.civil(1999, 12, 31, 19, 0 ,5), (twz + 5).time
    end
  end

  def test_plus_when_crossing_time_class_limit
    silence_warnings do # silence warnings raised by tzinfo gem
      twz = ActiveSupport::TimeWithZone.new(Time.utc(2038, 1, 19), @time_zone)
      assert_equal [0, 0, 19, 19, 1, 2038], (twz + 86_400).to_a[0,6]
    end
  end

  def test_plus_with_duration
    silence_warnings do # silence warnings raised by tzinfo gem
      assert_equal Time.utc(2000, 1, 5, 19, 0 ,0), (@twz + 5.days).time
    end
  end

  def test_minus_with_integer
    silence_warnings do # silence warnings raised by tzinfo gem
      assert_equal Time.utc(1999, 12, 31, 18, 59 ,55), (@twz - 5).time
    end
  end

  def test_minus_with_integer_when_self_wraps_datetime
    silence_warnings do # silence warnings raised by tzinfo gem
      datetime = DateTime.civil(2000, 1, 1, 0)
      twz = ActiveSupport::TimeWithZone.new(datetime, @time_zone)
      assert_equal DateTime.civil(1999, 12, 31, 18, 59 ,55), (twz - 5).time
    end
  end

  def test_minus_with_duration
    silence_warnings do # silence warnings raised by tzinfo gem
      assert_equal Time.utc(1999, 12, 26, 19, 0 ,0), (@twz - 5.days).time
    end
  end

  def test_minus_with_time
    assert_equal  86_400.0,  ActiveSupport::TimeWithZone.new( Time.utc(2000, 1, 2), ActiveSupport::TimeZone['UTC'] ) - Time.utc(2000, 1, 1)
    assert_equal  86_400.0,  ActiveSupport::TimeWithZone.new( Time.utc(2000, 1, 2), ActiveSupport::TimeZone['Hawaii'] ) - Time.utc(2000, 1, 1)
  end

  def test_minus_with_time_with_zone
    twz1 = ActiveSupport::TimeWithZone.new( Time.utc(2000, 1, 1), ActiveSupport::TimeZone['UTC'] )
    twz2 = ActiveSupport::TimeWithZone.new( Time.utc(2000, 1, 2), ActiveSupport::TimeZone['UTC'] )
    assert_equal  86_400.0,  twz2 - twz1
  end

  def test_plus_and_minus_enforce_spring_dst_rules
    silence_warnings do # silence warnings raised by tzinfo gem
      utc = Time.utc(2006,4,2,6,59,59) # == Apr 2 2006 01:59:59 EST; i.e., 1 second before daylight savings start
      twz = ActiveSupport::TimeWithZone.new(utc, @time_zone)
      assert_equal Time.utc(2006,4,2,1,59,59), twz.time
      assert_equal false, twz.dst?
      assert_equal 'EST', twz.zone
      twz = twz + 1
      assert_equal Time.utc(2006,4,2,3), twz.time # adding 1 sec springs forward to 3:00AM EDT
      assert_equal true, twz.dst?
      assert_equal 'EDT', twz.zone
      twz = twz - 1 # subtracting 1 second takes goes back to 1:59:59AM EST
      assert_equal Time.utc(2006,4,2,1,59,59), twz.time
      assert_equal false, twz.dst?
      assert_equal 'EST', twz.zone
    end
  end

  def test_plus_and_minus_enforce_fall_dst_rules
    silence_warnings do # silence warnings raised by tzinfo gem
      utc = Time.utc(2006,10,29,5,59,59) # == Oct 29 2006 01:59:59 EST; i.e., 1 second before daylight savings end
      twz = ActiveSupport::TimeWithZone.new(utc, @time_zone)
      assert_equal Time.utc(2006,10,29,1,59,59), twz.time
      assert_equal true, twz.dst?
      assert_equal 'EDT', twz.zone
      twz = twz + 1
      assert_equal Time.utc(2006,10,29,1), twz.time # adding 1 sec falls back from 1:59:59 EDT to 1:00AM EST
      assert_equal false, twz.dst?
      assert_equal 'EST', twz.zone
      twz = twz - 1
      assert_equal Time.utc(2006,10,29,1,59,59), twz.time # subtracting 1 sec goes back to 1:59:59AM EDT
      assert_equal true, twz.dst?
      assert_equal 'EDT', twz.zone
    end
  end

  def test_to_a
    silence_warnings do # silence warnings raised by tzinfo gem
      assert_equal [45, 30, 5, 1, 2, 2000, 2, 32, false, "HST"], ActiveSupport::TimeWithZone.new( Time.utc(2000, 2, 1, 15, 30, 45), ActiveSupport::TimeZone['Hawaii'] ).to_a
    end
  end

  def test_to_f
    result = ActiveSupport::TimeWithZone.new( Time.utc(2000, 1, 1), ActiveSupport::TimeZone['Hawaii'] ).to_f
    assert_equal 946684800.0, result
    assert result.is_a?(Float)
  end

  def test_to_i
    result = ActiveSupport::TimeWithZone.new( Time.utc(2000, 1, 1), ActiveSupport::TimeZone['Hawaii'] ).to_i
    assert_equal 946684800, result
    assert result.is_a?(Integer)
  end

  def test_to_time
    assert_equal @twz, @twz.to_time
  end

  def test_to_date
    silence_warnings do # silence warnings raised by tzinfo gem
      # 1 sec before midnight Jan 1 EST
      assert_equal Date.new(1999, 12, 31), ActiveSupport::TimeWithZone.new( Time.utc(2000, 1, 1, 4, 59, 59), ActiveSupport::TimeZone['Eastern Time (US & Canada)'] ).to_date
      # midnight Jan 1 EST
      assert_equal Date.new(2000,  1,  1), ActiveSupport::TimeWithZone.new( Time.utc(2000, 1, 1, 5,  0,  0), ActiveSupport::TimeZone['Eastern Time (US & Canada)'] ).to_date
      # 1 sec before midnight Jan 2 EST
      assert_equal Date.new(2000,  1,  1), ActiveSupport::TimeWithZone.new( Time.utc(2000, 1, 2, 4, 59, 59), ActiveSupport::TimeZone['Eastern Time (US & Canada)'] ).to_date
      # midnight Jan 2 EST
      assert_equal Date.new(2000,  1,  2), ActiveSupport::TimeWithZone.new( Time.utc(2000, 1, 2, 5,  0,  0), ActiveSupport::TimeZone['Eastern Time (US & Canada)'] ).to_date
    end
  end

  def test_to_datetime
    silence_warnings do # silence warnings raised by tzinfo gem
      assert_equal DateTime.civil(1999, 12, 31, 19, 0, 0, Rational(-18_000, 86_400)),  @twz.to_datetime
    end
  end

  def test_acts_like_time
    assert @twz.acts_like?(:time)
    assert ActiveSupport::TimeWithZone.new(DateTime.civil(2000), @time_zone).acts_like?(:time)
  end

  def test_acts_like_date
    assert_equal false, @twz.acts_like?(:date)
    assert_equal false, ActiveSupport::TimeWithZone.new(DateTime.civil(2000), @time_zone).acts_like?(:date)
  end

  def test_is_a
    assert @twz.is_a?(Time)
    assert @twz.kind_of?(Time)
    assert @twz.is_a?(ActiveSupport::TimeWithZone)
  end

  def test_method_missing_with_time_return_value
    silence_warnings do # silence warnings raised by tzinfo gem
      assert_instance_of ActiveSupport::TimeWithZone, @twz.months_since(1)
      assert_equal Time.utc(2000, 1, 31, 19, 0 ,0), @twz.months_since(1).time
    end
  end

  def test_marshal_dump_and_load
    silence_warnings do # silence warnings raised by tzinfo gem
      marshal_str = Marshal.dump(@twz)
      mtime = Marshal.load(marshal_str)
      assert_equal Time.utc(2000, 1, 1, 0), mtime.utc
      assert mtime.utc.utc?
      assert_equal ActiveSupport::TimeZone['Eastern Time (US & Canada)'], mtime.time_zone
      assert_equal Time.utc(1999, 12, 31, 19), mtime.time
      assert mtime.time.utc?
      assert_equal @twz.inspect, mtime.inspect
    end
  end

  def test_marshal_dump_and_load_with_tzinfo_identifier
    silence_warnings do # silence warnings raised by tzinfo gem
      twz = ActiveSupport::TimeWithZone.new(@utc, TZInfo::Timezone.get('America/New_York'))
      marshal_str = Marshal.dump(twz)
      mtime = Marshal.load(marshal_str)
      assert_equal Time.utc(2000, 1, 1, 0), mtime.utc
      assert mtime.utc.utc?
      assert_equal 'America/New_York', mtime.time_zone.name
      assert_equal Time.utc(1999, 12, 31, 19), mtime.time
      assert mtime.time.utc?
      assert_equal @twz.inspect, mtime.inspect
    end
  end

  uses_mocha 'TestDatePartValueMethods' do
    def test_method_missing_with_non_time_return_value
      silence_warnings do # silence warnings raised by tzinfo gem
        @twz.time.expects(:foo).returns('bar')
        assert_equal 'bar', @twz.foo
      end
    end

    def test_date_part_value_methods
      silence_warnings do # silence warnings raised by tzinfo gem
        twz = ActiveSupport::TimeWithZone.new(Time.utc(1999,12,31,19,18,17,500), @time_zone)
        twz.expects(:method_missing).never
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
  end

  def test_usec_returns_0_when_datetime_is_wrapped
    silence_warnings do # silence warnings raised by tzinfo gem
      twz = ActiveSupport::TimeWithZone.new(DateTime.civil(2000), @time_zone)
      assert_equal 0, twz.usec
    end
  end

  def test_utc_to_local_conversion_saves_period_in_instance_variable
    silence_warnings do # silence warnings raised by tzinfo gem
      assert_nil @twz.instance_variable_get('@period')
      @twz.time
      assert_kind_of TZInfo::TimezonePeriod, @twz.instance_variable_get('@period')
    end
  end

  def test_instance_created_with_local_time_returns_correct_utc_time
    silence_warnings do # silence warnings raised by tzinfo gem
      twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(1999, 12, 31, 19))
      assert_equal Time.utc(2000), twz.utc
    end
  end

  def test_instance_created_with_local_time_enforces_spring_dst_rules
    silence_warnings do # silence warnings raised by tzinfo gem
      twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2006,4,2,2)) # first second of DST
      assert_equal Time.utc(2006,4,2,3), twz.time # springs forward to 3AM
      assert_equal true, twz.dst?
      assert_equal 'EDT', twz.zone
    end
  end

  def test_instance_created_with_local_time_enforces_fall_dst_rules
    silence_warnings do # silence warnings raised by tzinfo gem
      twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2006,10,29,1)) # 1AM can be either DST or non-DST; we'll pick DST
      assert_equal Time.utc(2006,10,29,1), twz.time
      assert_equal true, twz.dst?
      assert_equal 'EDT', twz.zone
    end
  end

  def test_ruby_19_weekday_name_query_methods
    ruby_19_or_greater = RUBY_VERSION >= '1.9'
    %w(sunday? monday? tuesday? wednesday? thursday? friday? saturday?).each do |name|
      assert_equal ruby_19_or_greater, @twz.respond_to?(name)
    end
  end

  def test_utc_to_local_conversion_with_far_future_datetime
    silence_warnings do # silence warnings raised by tzinfo gem
      assert_equal [0,0,19,31,12,2049], ActiveSupport::TimeWithZone.new(DateTime.civil(2050), @time_zone).to_a[0,6]
    end
  end

  def test_local_to_utc_conversion_with_far_future_datetime
    silence_warnings do # silence warnings raised by tzinfo gem
      assert_equal DateTime.civil(2050).to_f, ActiveSupport::TimeWithZone.new(nil, @time_zone, DateTime.civil(2049,12,31,19)).to_f
    end
  end

  def test_change
    assert_equal "Fri, 31 Dec 1999 19:00:00 EST -05:00", @twz.inspect
    assert_equal "Mon, 31 Dec 2001 19:00:00 EST -05:00", @twz.change(:year => 2001).inspect
    assert_equal "Wed, 31 Mar 1999 19:00:00 EST -05:00", @twz.change(:month => 3).inspect
    assert_equal "Wed, 03 Mar 1999 19:00:00 EST -05:00", @twz.change(:month => 2).inspect
    assert_equal "Wed, 15 Dec 1999 19:00:00 EST -05:00", @twz.change(:day => 15).inspect
    assert_equal "Fri, 31 Dec 1999 06:00:00 EST -05:00", @twz.change(:hour => 6).inspect
    assert_equal "Fri, 31 Dec 1999 19:15:00 EST -05:00", @twz.change(:min => 15).inspect
    assert_equal "Fri, 31 Dec 1999 19:00:30 EST -05:00", @twz.change(:sec => 30).inspect
  end

  def test_advance
    assert_equal "Fri, 31 Dec 1999 19:00:00 EST -05:00", @twz.inspect
    assert_equal "Mon, 31 Dec 2001 19:00:00 EST -05:00", @twz.advance(:years => 2).inspect
    assert_equal "Fri, 31 Mar 2000 19:00:00 EST -05:00", @twz.advance(:months => 3).inspect
    assert_equal "Tue, 04 Jan 2000 19:00:00 EST -05:00", @twz.advance(:days => 4).inspect
    assert_equal "Sat, 01 Jan 2000 01:00:00 EST -05:00", @twz.advance(:hours => 6).inspect
    assert_equal "Fri, 31 Dec 1999 19:15:00 EST -05:00", @twz.advance(:minutes => 15).inspect
    assert_equal "Fri, 31 Dec 1999 19:00:30 EST -05:00", @twz.advance(:seconds => 30).inspect
  end

  def beginning_of_year
    assert_equal "Fri, 31 Dec 1999 19:00:00 EST -05:00", @twz.inspect
    assert_equal "Fri, 01 Jan 1999 00:00:00 EST -05:00", @twz.beginning_of_year.inspect
  end

  def end_of_year
    assert_equal "Fri, 31 Dec 1999 19:00:00 EST -05:00", @twz.inspect
    assert_equal "Fri, 31 Dec 1999 23:59:59 EST -05:00", @twz.end_of_year.inspect
  end

  def beginning_of_month
    assert_equal "Fri, 31 Dec 1999 19:00:00 EST -05:00", @twz.inspect
    assert_equal "Fri, 01 Dec 1999 00:00:00 EST -05:00", @twz.beginning_of_month.inspect
  end

  def end_of_month
    assert_equal "Fri, 31 Dec 1999 19:00:00 EST -05:00", @twz.inspect
    assert_equal "Fri, 31 Dec 1999 23:59:59 EST -05:00", @twz.end_of_month.inspect
  end

  def beginning_of_day
    assert_equal "Fri, 31 Dec 1999 19:00:00 EST -05:00", @twz.inspect
    assert_equal "Fri, 31 Dec 1999 00:00:00 EST -05:00", @twz.beginning_of_day.inspect
  end

  def end_of_day
    assert_equal "Fri, 31 Dec 1999 19:00:00 EST -05:00", @twz.inspect
    assert_equal "Fri, 31 Dec 1999 23:59:59 EST -05:00", @twz.end_of_day.inspect
  end

  def test_since
    assert_equal "Fri, 31 Dec 1999 19:00:01 EST -05:00", @twz.since(1).inspect
  end

  def test_ago
    assert_equal "Fri, 31 Dec 1999 18:59:59 EST -05:00", @twz.ago(1).inspect
  end

  def test_seconds_since_midnight
    assert_equal 19 * 60 * 60, @twz.seconds_since_midnight
  end

  def test_advance_1_year_from_leap_day
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2004,2,29))
    assert_equal "Mon, 28 Feb 2005 00:00:00 EST -05:00", twz.advance(:years => 1).inspect
    assert_equal "Mon, 28 Feb 2005 00:00:00 EST -05:00", twz.years_since(1).inspect
    assert_equal "Mon, 28 Feb 2005 00:00:00 EST -05:00", twz.since(1.year).inspect
    assert_equal "Mon, 28 Feb 2005 00:00:00 EST -05:00", (twz + 1.year).inspect
  end

  def test_advance_1_month_from_last_day_of_january
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2005,1,31))
    assert_equal "Mon, 28 Feb 2005 00:00:00 EST -05:00", twz.advance(:months => 1).inspect
    assert_equal "Mon, 28 Feb 2005 00:00:00 EST -05:00", twz.months_since(1).inspect
    assert_equal "Mon, 28 Feb 2005 00:00:00 EST -05:00", twz.since(1.month).inspect
    assert_equal "Mon, 28 Feb 2005 00:00:00 EST -05:00", (twz + 1.month).inspect
  end

  def test_advance_1_month_from_last_day_of_january_during_leap_year
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2000,1,31))
    assert_equal "Tue, 29 Feb 2000 00:00:00 EST -05:00", twz.advance(:months => 1).inspect
    assert_equal "Tue, 29 Feb 2000 00:00:00 EST -05:00", twz.months_since(1).inspect
    assert_equal "Tue, 29 Feb 2000 00:00:00 EST -05:00", twz.since(1.month).inspect
    assert_equal "Tue, 29 Feb 2000 00:00:00 EST -05:00", (twz + 1.month).inspect
  end

  def test_advance_1_month_into_spring_dst_gap
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2006,3,2,2))
    assert_equal "Sun, 02 Apr 2006 03:00:00 EDT -04:00", twz.advance(:months => 1).inspect
    assert_equal "Sun, 02 Apr 2006 03:00:00 EDT -04:00", twz.months_since(1).inspect
    assert_equal "Sun, 02 Apr 2006 03:00:00 EDT -04:00", twz.since(1.month).inspect
    assert_equal "Sun, 02 Apr 2006 03:00:00 EDT -04:00", (twz + 1.month).inspect
  end

  def test_advance_1_second_into_spring_dst_gap
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2006,4,2,1,59,59))
    assert_equal "Sun, 02 Apr 2006 03:00:00 EDT -04:00", twz.advance(:seconds => 1).inspect
    assert_equal "Sun, 02 Apr 2006 03:00:00 EDT -04:00", (twz + 1).inspect
    assert_equal "Sun, 02 Apr 2006 03:00:00 EDT -04:00", twz.since(1).inspect
    assert_equal "Sun, 02 Apr 2006 03:00:00 EDT -04:00", twz.since(1.second).inspect
    assert_equal "Sun, 02 Apr 2006 03:00:00 EDT -04:00", (twz + 1.second).inspect
  end

  def test_advance_1_day_across_spring_dst_transition
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2006,4,1,10,30))
    # In 2006, spring DST transition occurred Apr 2 at 2AM; this day was only 23 hours long
    # When we advance 1 day, we want to end up at the same time on the next day
    assert_equal "Sun, 02 Apr 2006 10:30:00 EDT -04:00", twz.advance(:days => 1).inspect
    assert_equal "Sun, 02 Apr 2006 10:30:00 EDT -04:00", twz.since(1.days).inspect
    assert_equal "Sun, 02 Apr 2006 10:30:00 EDT -04:00", (twz + 1.days).inspect
    assert_equal "Sun, 02 Apr 2006 10:30:01 EDT -04:00", twz.since(1.days + 1.second).inspect
    assert_equal "Sun, 02 Apr 2006 10:30:01 EDT -04:00", (twz + 1.days + 1.second).inspect
  end

  def test_advance_1_day_across_spring_dst_transition_backwards
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2006,4,2,10,30))
    # In 2006, spring DST transition occurred Apr 2 at 2AM; this day was only 23 hours long
    # When we advance back 1 day, we want to end up at the same time on the previous day
    assert_equal "Sat, 01 Apr 2006 10:30:00 EST -05:00", twz.advance(:days => -1).inspect
    assert_equal "Sat, 01 Apr 2006 10:30:00 EST -05:00", twz.ago(1.days).inspect
    assert_equal "Sat, 01 Apr 2006 10:30:00 EST -05:00", (twz - 1.days).inspect
    assert_equal "Sat, 01 Apr 2006 10:30:01 EST -05:00", twz.ago(1.days - 1.second).inspect
  end

  def test_advance_1_day_expressed_as_number_of_seconds_minutes_or_hours_across_spring_dst_transition
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2006,4,1,10,30))
    # In 2006, spring DST transition occurred Apr 2 at 2AM; this day was only 23 hours long
    # When we advance a specific number of hours, minutes or seconds, we want to advance exactly that amount
    assert_equal "Sun, 02 Apr 2006 11:30:00 EDT -04:00", (twz + 86400).inspect
    assert_equal "Sun, 02 Apr 2006 11:30:00 EDT -04:00", (twz + 86400.seconds).inspect
    assert_equal "Sun, 02 Apr 2006 11:30:00 EDT -04:00", twz.since(86400).inspect
    assert_equal "Sun, 02 Apr 2006 11:30:00 EDT -04:00", twz.since(86400.seconds).inspect
    assert_equal "Sun, 02 Apr 2006 11:30:00 EDT -04:00", twz.advance(:seconds => 86400).inspect
    assert_equal "Sun, 02 Apr 2006 11:30:00 EDT -04:00", (twz + 1440.minutes).inspect
    assert_equal "Sun, 02 Apr 2006 11:30:00 EDT -04:00", twz.since(1440.minutes).inspect
    assert_equal "Sun, 02 Apr 2006 11:30:00 EDT -04:00", twz.advance(:minutes => 1440).inspect
    assert_equal "Sun, 02 Apr 2006 11:30:00 EDT -04:00", (twz + 24.hours).inspect
    assert_equal "Sun, 02 Apr 2006 11:30:00 EDT -04:00", twz.since(24.hours).inspect
    assert_equal "Sun, 02 Apr 2006 11:30:00 EDT -04:00", twz.advance(:hours => 24).inspect
  end

  def test_advance_1_day_expressed_as_number_of_seconds_minutes_or_hours_across_spring_dst_transition_backwards
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2006,4,2,11,30))
    # In 2006, spring DST transition occurred Apr 2 at 2AM; this day was only 23 hours long
    # When we advance a specific number of hours, minutes or seconds, we want to advance exactly that amount
    assert_equal "Sat, 01 Apr 2006 10:30:00 EST -05:00", (twz - 86400).inspect
    assert_equal "Sat, 01 Apr 2006 10:30:00 EST -05:00", (twz - 86400.seconds).inspect
    assert_equal "Sat, 01 Apr 2006 10:30:00 EST -05:00", twz.ago(86400).inspect
    assert_equal "Sat, 01 Apr 2006 10:30:00 EST -05:00", twz.ago(86400.seconds).inspect
    assert_equal "Sat, 01 Apr 2006 10:30:00 EST -05:00", twz.advance(:seconds => -86400).inspect
    assert_equal "Sat, 01 Apr 2006 10:30:00 EST -05:00", (twz - 1440.minutes).inspect
    assert_equal "Sat, 01 Apr 2006 10:30:00 EST -05:00", twz.ago(1440.minutes).inspect
    assert_equal "Sat, 01 Apr 2006 10:30:00 EST -05:00", twz.advance(:minutes => -1440).inspect
    assert_equal "Sat, 01 Apr 2006 10:30:00 EST -05:00", (twz - 24.hours).inspect
    assert_equal "Sat, 01 Apr 2006 10:30:00 EST -05:00", twz.ago(24.hours).inspect
    assert_equal "Sat, 01 Apr 2006 10:30:00 EST -05:00", twz.advance(:hours => -24).inspect
  end

  def test_advance_1_day_across_fall_dst_transition
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2006,10,28,10,30))
    # In 2006, fall DST transition occurred Oct 29 at 2AM; this day was 25 hours long
    # When we advance 1 day, we want to end up at the same time on the next day
    assert_equal "Sun, 29 Oct 2006 10:30:00 EST -05:00", twz.advance(:days => 1).inspect
    assert_equal "Sun, 29 Oct 2006 10:30:00 EST -05:00", twz.since(1.days).inspect
    assert_equal "Sun, 29 Oct 2006 10:30:00 EST -05:00", (twz + 1.days).inspect
    assert_equal "Sun, 29 Oct 2006 10:30:01 EST -05:00", twz.since(1.days + 1.second).inspect
    assert_equal "Sun, 29 Oct 2006 10:30:01 EST -05:00", (twz + 1.days + 1.second).inspect
  end

  def test_advance_1_day_across_fall_dst_transition_backwards
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2006,10,29,10,30))
    # In 2006, fall DST transition occurred Oct 29 at 2AM; this day was 25 hours long
    # When we advance backwards 1 day, we want to end up at the same time on the previous day
    assert_equal "Sat, 28 Oct 2006 10:30:00 EDT -04:00", twz.advance(:days => -1).inspect
    assert_equal "Sat, 28 Oct 2006 10:30:00 EDT -04:00", twz.ago(1.days).inspect
    assert_equal "Sat, 28 Oct 2006 10:30:00 EDT -04:00", (twz - 1.days).inspect
    assert_equal "Sat, 28 Oct 2006 10:30:01 EDT -04:00", twz.ago(1.days - 1.second).inspect
  end

  def test_advance_1_day_expressed_as_number_of_seconds_minutes_or_hours_across_fall_dst_transition
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2006,10,28,10,30))
    # In 2006, fall DST transition occurred Oct 29 at 2AM; this day was 25 hours long
    # When we advance a specific number of hours, minutes or seconds, we want to advance exactly that amount
    assert_equal "Sun, 29 Oct 2006 09:30:00 EST -05:00", (twz + 86400).inspect
    assert_equal "Sun, 29 Oct 2006 09:30:00 EST -05:00", (twz + 86400.seconds).inspect
    assert_equal "Sun, 29 Oct 2006 09:30:00 EST -05:00", twz.since(86400).inspect
    assert_equal "Sun, 29 Oct 2006 09:30:00 EST -05:00", twz.since(86400.seconds).inspect
    assert_equal "Sun, 29 Oct 2006 09:30:00 EST -05:00", twz.advance(:seconds => 86400).inspect
    assert_equal "Sun, 29 Oct 2006 09:30:00 EST -05:00", (twz + 1440.minutes).inspect
    assert_equal "Sun, 29 Oct 2006 09:30:00 EST -05:00", twz.since(1440.minutes).inspect
    assert_equal "Sun, 29 Oct 2006 09:30:00 EST -05:00", twz.advance(:minutes => 1440).inspect
    assert_equal "Sun, 29 Oct 2006 09:30:00 EST -05:00", (twz + 24.hours).inspect
    assert_equal "Sun, 29 Oct 2006 09:30:00 EST -05:00", twz.since(24.hours).inspect
    assert_equal "Sun, 29 Oct 2006 09:30:00 EST -05:00", twz.advance(:hours => 24).inspect
  end

  def test_advance_1_day_expressed_as_number_of_seconds_minutes_or_hours_across_fall_dst_transition_backwards
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2006,10,29,9,30))
    # In 2006, fall DST transition occurred Oct 29 at 2AM; this day was 25 hours long
    # When we advance a specific number of hours, minutes or seconds, we want to advance exactly that amount
    assert_equal "Sat, 28 Oct 2006 10:30:00 EDT -04:00", (twz - 86400).inspect
    assert_equal "Sat, 28 Oct 2006 10:30:00 EDT -04:00", (twz - 86400.seconds).inspect
    assert_equal "Sat, 28 Oct 2006 10:30:00 EDT -04:00", twz.ago(86400).inspect
    assert_equal "Sat, 28 Oct 2006 10:30:00 EDT -04:00", twz.ago(86400.seconds).inspect
    assert_equal "Sat, 28 Oct 2006 10:30:00 EDT -04:00", twz.advance(:seconds => -86400).inspect
    assert_equal "Sat, 28 Oct 2006 10:30:00 EDT -04:00", (twz - 1440.minutes).inspect
    assert_equal "Sat, 28 Oct 2006 10:30:00 EDT -04:00", twz.ago(1440.minutes).inspect
    assert_equal "Sat, 28 Oct 2006 10:30:00 EDT -04:00", twz.advance(:minutes => -1440).inspect
    assert_equal "Sat, 28 Oct 2006 10:30:00 EDT -04:00", (twz - 24.hours).inspect
    assert_equal "Sat, 28 Oct 2006 10:30:00 EDT -04:00", twz.ago(24.hours).inspect
    assert_equal "Sat, 28 Oct 2006 10:30:00 EDT -04:00", twz.advance(:hours => -24).inspect
  end

  def test_advance_1_month_across_spring_dst_transition
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2006,4,1,10,30))
    assert_equal "Mon, 01 May 2006 10:30:00 EDT -04:00", twz.advance(:months => 1).inspect
    assert_equal "Mon, 01 May 2006 10:30:00 EDT -04:00", twz.months_since(1).inspect
    assert_equal "Mon, 01 May 2006 10:30:00 EDT -04:00", twz.since(1.month).inspect
    assert_equal "Mon, 01 May 2006 10:30:00 EDT -04:00", (twz + 1.month).inspect
  end

  def test_advance_1_month_across_spring_dst_transition_backwards
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2006,5,1,10,30))
    assert_equal "Sat, 01 Apr 2006 10:30:00 EST -05:00", twz.advance(:months => -1).inspect
    assert_equal "Sat, 01 Apr 2006 10:30:00 EST -05:00", twz.months_ago(1).inspect
    assert_equal "Sat, 01 Apr 2006 10:30:00 EST -05:00", twz.ago(1.month).inspect
    assert_equal "Sat, 01 Apr 2006 10:30:00 EST -05:00", (twz - 1.month).inspect
  end

  def test_advance_1_month_across_fall_dst_transition
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2006,10,28,10,30))
    assert_equal "Tue, 28 Nov 2006 10:30:00 EST -05:00", twz.advance(:months => 1).inspect
    assert_equal "Tue, 28 Nov 2006 10:30:00 EST -05:00", twz.months_since(1).inspect
    assert_equal "Tue, 28 Nov 2006 10:30:00 EST -05:00", twz.since(1.month).inspect
    assert_equal "Tue, 28 Nov 2006 10:30:00 EST -05:00", (twz + 1.month).inspect
  end

  def test_advance_1_month_across_fall_dst_transition_backwards
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2006,11,28,10,30))
    assert_equal "Sat, 28 Oct 2006 10:30:00 EDT -04:00", twz.advance(:months => -1).inspect
    assert_equal "Sat, 28 Oct 2006 10:30:00 EDT -04:00", twz.months_ago(1).inspect
    assert_equal "Sat, 28 Oct 2006 10:30:00 EDT -04:00", twz.ago(1.month).inspect
    assert_equal "Sat, 28 Oct 2006 10:30:00 EDT -04:00", (twz - 1.month).inspect
  end

  def test_advance_1_year
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2008,2,15,10,30))
    assert_equal "Sun, 15 Feb 2009 10:30:00 EST -05:00", twz.advance(:years => 1).inspect
    assert_equal "Sun, 15 Feb 2009 10:30:00 EST -05:00", twz.years_since(1).inspect
    assert_equal "Sun, 15 Feb 2009 10:30:00 EST -05:00", (twz + 1.year).inspect
    assert_equal "Thu, 15 Feb 2007 10:30:00 EST -05:00", twz.advance(:years => -1).inspect
    assert_equal "Thu, 15 Feb 2007 10:30:00 EST -05:00", twz.years_ago(1).inspect
    assert_equal "Thu, 15 Feb 2007 10:30:00 EST -05:00", (twz - 1.year).inspect
  end

  def test_advance_1_year_during_dst
    twz = ActiveSupport::TimeWithZone.new(nil, @time_zone, Time.utc(2008,7,15,10,30))
    assert_equal "Wed, 15 Jul 2009 10:30:00 EDT -04:00", twz.advance(:years => 1).inspect
    assert_equal "Wed, 15 Jul 2009 10:30:00 EDT -04:00", twz.years_since(1).inspect
    assert_equal "Wed, 15 Jul 2009 10:30:00 EDT -04:00", (twz + 1.year).inspect
    assert_equal "Sun, 15 Jul 2007 10:30:00 EDT -04:00", twz.advance(:years => -1).inspect
    assert_equal "Sun, 15 Jul 2007 10:30:00 EDT -04:00", twz.years_ago(1).inspect
    assert_equal "Sun, 15 Jul 2007 10:30:00 EDT -04:00", (twz - 1.year).inspect
  end
  
  protected
    def with_env_tz(new_tz = 'US/Eastern')
      old_tz, ENV['TZ'] = ENV['TZ'], new_tz
      yield
    ensure
      old_tz ? ENV['TZ'] = old_tz : ENV.delete('TZ')
    end
end

class TimeWithZoneMethodsForTimeAndDateTimeTest < Test::Unit::TestCase
  def setup
    @t, @dt = Time.utc(2000), DateTime.civil(2000)
  end

  def teardown
    Time.zone = nil
  end

  def test_in_time_zone
    silence_warnings do # silence warnings raised by tzinfo gem
      Time.use_zone 'Alaska' do
        assert_equal 'Fri, 31 Dec 1999 15:00:00 AKST -09:00', @t.in_time_zone.inspect
        assert_equal 'Fri, 31 Dec 1999 15:00:00 AKST -09:00', @dt.in_time_zone.inspect
      end
      Time.use_zone 'Hawaii' do
        assert_equal 'Fri, 31 Dec 1999 14:00:00 HST -10:00', @t.in_time_zone.inspect
        assert_equal 'Fri, 31 Dec 1999 14:00:00 HST -10:00', @dt.in_time_zone.inspect
      end
      Time.use_zone nil do
        assert_equal @t, @t.in_time_zone
        assert_equal @dt, @dt.in_time_zone
      end
    end
  end

  def test_in_time_zone_with_argument
    silence_warnings do # silence warnings raised by tzinfo gem
      Time.use_zone 'Eastern Time (US & Canada)' do # Time.zone will not affect #in_time_zone(zone)
        assert_equal 'Fri, 31 Dec 1999 15:00:00 AKST -09:00', @t.in_time_zone('Alaska').inspect
        assert_equal 'Fri, 31 Dec 1999 15:00:00 AKST -09:00', @dt.in_time_zone('Alaska').inspect
        assert_equal 'Fri, 31 Dec 1999 14:00:00 HST -10:00', @t.in_time_zone('Hawaii').inspect
        assert_equal 'Fri, 31 Dec 1999 14:00:00 HST -10:00', @dt.in_time_zone('Hawaii').inspect
        assert_equal 'Sat, 01 Jan 2000 00:00:00 UTC +00:00', @t.in_time_zone('UTC').inspect
        assert_equal 'Sat, 01 Jan 2000 00:00:00 UTC +00:00', @dt.in_time_zone('UTC').inspect
        assert_equal 'Fri, 31 Dec 1999 15:00:00 AKST -09:00', @t.in_time_zone(-9.hours).inspect
      end
    end
  end

  def test_in_time_zone_with_time_local_instance
    silence_warnings do # silence warnings raised by tzinfo gem
      with_env_tz 'US/Eastern' do
        time = Time.local(1999, 12, 31, 19) # == Time.utc(2000)
        assert_equal 'Fri, 31 Dec 1999 15:00:00 AKST -09:00', time.in_time_zone('Alaska').inspect
      end
    end
  end

  def test_use_zone
    Time.zone = 'Alaska'
    Time.use_zone 'Hawaii' do
      assert_equal ActiveSupport::TimeZone['Hawaii'], Time.zone
    end
    assert_equal ActiveSupport::TimeZone['Alaska'], Time.zone
  end

  def test_use_zone_with_exception_raised
    Time.zone = 'Alaska'
    assert_raises RuntimeError do
      Time.use_zone('Hawaii') { raise RuntimeError }
    end
    assert_equal ActiveSupport::TimeZone['Alaska'], Time.zone
  end

  def test_time_zone_getter_and_setter
    Time.zone = ActiveSupport::TimeZone['Alaska']
    assert_equal ActiveSupport::TimeZone['Alaska'], Time.zone
    Time.zone = 'Alaska'
    assert_equal ActiveSupport::TimeZone['Alaska'], Time.zone
    Time.zone = -9.hours
    assert_equal ActiveSupport::TimeZone['Alaska'], Time.zone
    Time.zone = nil
    assert_equal nil, Time.zone
  end

  def test_time_zone_getter_and_setter_with_zone_default
    Time.zone_default = ActiveSupport::TimeZone['Alaska']
    assert_equal ActiveSupport::TimeZone['Alaska'], Time.zone
    Time.zone = ActiveSupport::TimeZone['Hawaii']
    assert_equal ActiveSupport::TimeZone['Hawaii'], Time.zone
    Time.zone = nil
    assert_equal ActiveSupport::TimeZone['Alaska'], Time.zone
  ensure
    Time.zone_default = nil
  end

  def test_time_zone_setter_is_thread_safe
    Time.use_zone 'Paris' do
      t1 = Thread.new { Time.zone = 'Alaska' }.join
      t2 = Thread.new { Time.zone = 'Hawaii' }.join
      assert t1.stop?, "Thread 1 did not finish running"
      assert t2.stop?, "Thread 2 did not finish running"
      assert_equal ActiveSupport::TimeZone['Paris'], Time.zone
      assert_equal ActiveSupport::TimeZone['Alaska'], t1[:time_zone]
      assert_equal ActiveSupport::TimeZone['Hawaii'], t2[:time_zone]
    end
  end

  def test_time_zone_setter_with_tzinfo_timezone_object_wraps_in_rails_time_zone
    silence_warnings do # silence warnings raised by tzinfo gem
      tzinfo = TZInfo::Timezone.get('America/New_York')
      Time.zone = tzinfo
      assert_kind_of ActiveSupport::TimeZone, Time.zone
      assert_equal tzinfo, Time.zone.tzinfo
      assert_equal 'America/New_York', Time.zone.name
      assert_equal(-18_000, Time.zone.utc_offset)
    end
  end

  def test_time_zone_setter_with_tzinfo_timezone_identifier_does_lookup_and_wraps_in_rails_time_zone
    silence_warnings do # silence warnings raised by tzinfo gem
      Time.zone = 'America/New_York'
      assert_kind_of ActiveSupport::TimeZone, Time.zone
      assert_equal 'America/New_York', Time.zone.tzinfo.name
      assert_equal 'America/New_York', Time.zone.name
      assert_equal(-18_000, Time.zone.utc_offset)
    end
  end

  def test_time_zone_setter_with_non_identifying_argument_returns_nil
    Time.zone = 'foo'
    assert_equal nil, Time.zone
    Time.zone = -15.hours
    assert_equal nil, Time.zone
  end

  uses_mocha 'TestTimeCurrent' do
    def test_current_returns_time_now_when_zone_default_not_set
      with_env_tz 'US/Eastern' do
        Time.stubs(:now).returns Time.local(2000)
        assert_equal false, Time.current.is_a?(ActiveSupport::TimeWithZone)
        assert_equal Time.local(2000), Time.current
      end
    end

    def test_current_returns_time_zone_now_when_zone_default_set
      silence_warnings do # silence warnings raised by tzinfo gem
        Time.zone_default = ActiveSupport::TimeZone['Eastern Time (US & Canada)']
        with_env_tz 'US/Eastern' do
          Time.stubs(:now).returns Time.local(2000)
          assert_equal true, Time.current.is_a?(ActiveSupport::TimeWithZone)
          assert_equal 'Eastern Time (US & Canada)', Time.current.time_zone.name
          assert_equal Time.utc(2000), Time.current.time
        end
      end
    ensure
      Time.zone_default = nil
    end
  end

  protected
    def with_env_tz(new_tz = 'US/Eastern')
      old_tz, ENV['TZ'] = ENV['TZ'], new_tz
      yield
    ensure
      old_tz ? ENV['TZ'] = old_tz : ENV.delete('TZ')
    end
end
