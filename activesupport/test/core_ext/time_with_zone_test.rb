require 'abstract_unit'

uses_tzinfo 'TimeWithZoneTest' do
  
  class TimeWithZoneTest < Test::Unit::TestCase

    def setup
      @utc = Time.utc(2000, 1, 1, 0)
      @time_zone = TimeZone['Eastern Time (US & Canada)']
      @twz = ActiveSupport::TimeWithZone.new(@utc, @time_zone)
    end
  
    def test_utc
      assert_equal @utc, @twz.utc
    end
  
    def test_time
      assert_equal Time.utc(1999, 12, 31, 19), @twz.time
    end
  
    def test_time_zone
      assert_equal @time_zone, @twz.time_zone
    end
  
    def test_in_time_zone
      assert_equal ActiveSupport::TimeWithZone.new(@utc, TimeZone['Alaska']), @twz.in_time_zone('Alaska')
    end
    
    def test_in_time_zone_with_new_zone_equal_to_old_zone_does_not_create_new_object
      assert_equal @twz.object_id, @twz.in_time_zone(TimeZone['Eastern Time (US & Canada)']).object_id
    end
  
    def test_in_current_time_zone
      Time.use_zone 'Alaska' do
        assert_equal ActiveSupport::TimeWithZone.new(@utc, TimeZone['Alaska']), @twz.in_current_time_zone
      end
    end
  
    def test_change_time_zone
      silence_warnings do # silence warnings raised by tzinfo gem
        assert_equal ActiveSupport::TimeWithZone.new(nil, TimeZone['Alaska'], Time.utc(1999, 12, 31, 19)), @twz.change_time_zone('Alaska')
      end
    end
  
    def test_utc?
      assert_equal false, @twz.utc?
      assert_equal true, ActiveSupport::TimeWithZone.new(Time.utc(2000), TimeZone['UTC']).utc?
    end
      
    def test_formatted_offset
      assert_equal '-05:00', @twz.formatted_offset
      assert_equal '-04:00', ActiveSupport::TimeWithZone.new(Time.utc(2000, 6), @time_zone).formatted_offset #dst
    end
      
    def test_dst?
      assert_equal false, @twz.dst?
      assert_equal true, ActiveSupport::TimeWithZone.new(Time.utc(2000, 6), @time_zone).dst?
    end
      
    def test_zone
      assert_equal 'EST', @twz.zone
      assert_equal 'EDT', ActiveSupport::TimeWithZone.new(Time.utc(2000, 6), @time_zone).zone #dst
    end
      
    def test_to_json
      assert_equal "\"1999/12/31 19:00:00 -0500\"", @twz.to_json
    end
      
    def test_strftime
      assert_equal '1999-12-31 19:00:00 EST -0500', @twz.strftime('%Y-%m-%d %H:%M:%S %Z %z')
    end
      
    def test_inspect
      assert_equal 'Fri, 31 Dec 1999 19:00:00 EST -05:00', @twz.inspect
    end
      
    def test_to_s
      assert_equal '1999-12-31 19:00:00 -0500', @twz.to_s
    end
      
    def test_to_s_db
      assert_equal '2000-01-01 00:00:00', @twz.to_s(:db)
    end
      
    def test_xmlschema
      assert_equal "1999-12-31T19:00:00-05:00", @twz.xmlschema
    end
    
    def test_httpdate
      assert_equal 'Sat, 01 Jan 2000 00:00:00 GMT', @twz.httpdate
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
      assert_equal  1, @twz <=> ActiveSupport::TimeWithZone.new( Time.utc(1999, 12, 31, 23, 59, 59), TimeZone['UTC'] )
      assert_equal  0, @twz <=> ActiveSupport::TimeWithZone.new( Time.utc(2000, 1, 1, 0, 0, 0), TimeZone['UTC'] )
      assert_equal(-1, @twz <=> ActiveSupport::TimeWithZone.new( Time.utc(2000, 1, 1, 0, 0, 1), TimeZone['UTC'] ))
    end
      
    def test_plus
      assert_equal Time.utc(1999, 12, 31, 19, 0 ,5), (@twz + 5).time
    end
      
    def test_plus_with_duration
      assert_equal Time.utc(2000, 1, 5, 19, 0 ,0), (@twz + 5.days).time
    end
      
    def test_minus
      assert_equal Time.utc(1999, 12, 31, 18, 59 ,55), (@twz - 5).time
    end
      
    def test_minus_with_duration
      assert_equal Time.utc(1999, 12, 26, 19, 0 ,0), (@twz - 5.days).time
    end
    
    def test_minus_with_time
      assert_equal  86_400.0,  ActiveSupport::TimeWithZone.new( Time.utc(2000, 1, 2), TimeZone['UTC'] ) - Time.utc(2000, 1, 1)
      assert_equal  86_400.0,  ActiveSupport::TimeWithZone.new( Time.utc(2000, 1, 2), TimeZone['Hawaii'] ) - Time.utc(2000, 1, 1)
    end
    
    def test_minus_with_time_with_zone
      twz1 = ActiveSupport::TimeWithZone.new( Time.utc(2000, 1, 1), TimeZone['UTC'] )
      twz2 = ActiveSupport::TimeWithZone.new( Time.utc(2000, 1, 2), TimeZone['UTC'] )
      assert_equal  86_400.0,  twz2 - twz1
    end
    
    def test_to_a
      assert_equal [45, 30, 5, 1, 2, 2000, 2, 32, false, "HST"], ActiveSupport::TimeWithZone.new( Time.utc(2000, 2, 1, 15, 30, 45), TimeZone['Hawaii'] ).to_a
    end
    
    def test_to_f
      result = ActiveSupport::TimeWithZone.new( Time.utc(2000, 1, 1), TimeZone['Hawaii'] ).to_f
      assert_equal 946684800.0, result
      assert result.is_a?(Float)
    end
    
    def test_to_i
      result = ActiveSupport::TimeWithZone.new( Time.utc(2000, 1, 1), TimeZone['Hawaii'] ).to_i
      assert_equal 946684800, result
      assert result.is_a?(Integer)
    end
      
    def test_to_time
      assert_equal @twz, @twz.to_time
    end
      
    def test_acts_like_time
      assert @twz.acts_like?(:time)
    end
    
    def test_is_a
      assert @twz.is_a?(Time)
      assert @twz.kind_of?(Time)
      assert @twz.is_a?(ActiveSupport::TimeWithZone)
    end
      
    def test_method_missing_with_time_return_value
      assert_instance_of ActiveSupport::TimeWithZone, @twz.months_since(1)
      assert_equal Time.utc(2000, 1, 31, 19, 0 ,0), @twz.months_since(1).time
    end
      
    def test_method_missing_with_non_time_return_value
      assert_equal 1999, @twz.year
      assert_equal 12, @twz.month
      assert_equal 31, @twz.day
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

    def test_in_current_time_zone
      Time.use_zone 'Alaska' do
        assert_equal 'Fri, 31 Dec 1999 15:00:00 AKST -09:00', @t.in_current_time_zone.inspect
        assert_equal 'Fri, 31 Dec 1999 15:00:00 AKST -09:00', @dt.in_current_time_zone.inspect
      end
      Time.use_zone 'Hawaii' do
        assert_equal 'Fri, 31 Dec 1999 14:00:00 HST -10:00', @t.in_current_time_zone.inspect
        assert_equal 'Fri, 31 Dec 1999 14:00:00 HST -10:00', @dt.in_current_time_zone.inspect
      end
      Time.use_zone nil do
        assert_equal @t, @t.in_current_time_zone
        assert_equal @dt, @dt.in_current_time_zone
      end
    end
    
    def test_change_time_zone
      silence_warnings do # silence warnings raised by tzinfo gem
        Time.use_zone 'Eastern Time (US & Canada)' do # Time.zone will not affect #change_time_zone(zone)
          assert_equal 'Sat, 01 Jan 2000 00:00:00 AKST -09:00', @t.change_time_zone('Alaska').inspect
          assert_equal 'Sat, 01 Jan 2000 00:00:00 AKST -09:00', @dt.change_time_zone('Alaska').inspect
          assert_equal 'Sat, 01 Jan 2000 00:00:00 HST -10:00', @t.change_time_zone('Hawaii').inspect
          assert_equal 'Sat, 01 Jan 2000 00:00:00 HST -10:00', @dt.change_time_zone('Hawaii').inspect
          assert_equal 'Sat, 01 Jan 2000 00:00:00 UTC +00:00', @t.change_time_zone('UTC').inspect
          assert_equal 'Sat, 01 Jan 2000 00:00:00 UTC +00:00', @dt.change_time_zone('UTC').inspect
          assert_equal 'Sat, 01 Jan 2000 00:00:00 AKST -09:00', @t.change_time_zone(-9.hours).inspect
        end
      end
    end
    
    def test_use_zone
      Time.zone = 'Alaska'
      Time.use_zone 'Hawaii' do
        assert_equal TimeZone['Hawaii'], Time.zone
      end
      assert_equal TimeZone['Alaska'], Time.zone
    end
    
    def test_use_zone_with_exception_raised
      Time.zone = 'Alaska'
      assert_raises RuntimeError do
        Time.use_zone('Hawaii') { raise RuntimeError }
      end
      assert_equal TimeZone['Alaska'], Time.zone
    end
    
    def test_time_zone_getter_and_setter
      Time.zone = TimeZone['Alaska']
      assert_equal TimeZone['Alaska'], Time.zone
      Time.zone = 'Alaska'
      assert_equal TimeZone['Alaska'], Time.zone
      Time.zone = -9.hours
      assert_equal TimeZone['Alaska'], Time.zone
      Time.zone = nil
      assert_equal nil, Time.zone
    end
    
    def test_time_zone_getter_and_setter_with_zone_default
      Time.zone_default = TimeZone['Alaska']
      assert_equal TimeZone['Alaska'], Time.zone
      Time.zone = TimeZone['Hawaii']
      assert_equal TimeZone['Hawaii'], Time.zone
      Time.zone = nil
      assert_equal TimeZone['Alaska'], Time.zone
    ensure
      Time.zone_default = nil
    end
    
    def test_time_zone_setter_is_thread_safe
      Time.use_zone 'Paris' do
        t1 = Thread.new { Time.zone = 'Alaska' }
        t2 = Thread.new { Time.zone = 'Hawaii' }
        assert_equal TimeZone['Paris'], Time.zone
        assert_equal TimeZone['Alaska'], t1[:time_zone]
        assert_equal TimeZone['Hawaii'], t2[:time_zone]
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
end
