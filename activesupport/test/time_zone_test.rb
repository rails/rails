require 'abstract_unit'

class TimeZoneTest < Test::Unit::TestCase
  
  uses_tzinfo 'TestTimeZoneCalculations' do
    
    def test_utc_to_local
      silence_warnings do # silence warnings raised by tzinfo gem
        zone = TimeZone['Eastern Time (US & Canada)']
        assert_equal Time.utc(1999, 12, 31, 19), zone.utc_to_local(Time.utc(2000, 1)) # standard offset -0500
        assert_equal Time.utc(2000, 6, 30, 20), zone.utc_to_local(Time.utc(2000, 7)) # dst offset -0400
      end
    end
  
    def test_local_to_utc
      silence_warnings do # silence warnings raised by tzinfo gem
        zone = TimeZone['Eastern Time (US & Canada)']
        assert_equal Time.utc(2000, 1, 1, 5), zone.local_to_utc(Time.utc(2000, 1)) # standard offset -0500
        assert_equal Time.utc(2000, 7, 1, 4), zone.local_to_utc(Time.utc(2000, 7)) # dst offset -0400
      end
    end
    
    def test_period_for_local
      silence_warnings do # silence warnings raised by tzinfo gem
        zone = TimeZone['Eastern Time (US & Canada)']
        assert_instance_of TZInfo::TimezonePeriod, zone.period_for_local(Time.utc(2000))
      end
    end
    
    TimeZone::MAPPING.keys.each do |name|
      define_method("test_map_#{name.downcase.gsub(/[^a-z]/, '_')}_to_tzinfo") do
        silence_warnings do # silence warnings raised by tzinfo gem
          zone = TimeZone[name]
          assert zone.tzinfo.respond_to?(:period_for_local)
        end
      end
    end

    def test_from_integer_to_map
      assert_instance_of TimeZone, TimeZone[-28800] # PST
    end

    def test_from_duration_to_map
      assert_instance_of TimeZone, TimeZone[-480.minutes] # PST
    end

    TimeZone.all.each do |zone|
      name = zone.name.downcase.gsub(/[^a-z]/, '_')
      define_method("test_from_#{name}_to_map") do
        silence_warnings do # silence warnings raised by tzinfo gem
          assert_instance_of TimeZone, TimeZone[zone.name]
        end
      end

      define_method("test_utc_offset_for_#{name}") do
        silence_warnings do # silence warnings raised by tzinfo gem
          period = zone.tzinfo.period_for_utc(Time.utc(2006,1,1,0,0,0))
          assert_equal period.utc_offset, zone.utc_offset
        end
      end
    end

    uses_mocha 'TestTimeZoneNowAndToday' do
      def test_now
        with_env_tz 'US/Eastern' do
          Time.stubs(:now).returns(Time.local(2000))
          zone = TimeZone['Eastern Time (US & Canada)']
          assert_instance_of ActiveSupport::TimeWithZone, zone.now
          assert_equal Time.utc(2000,1,1,5), zone.now.utc
          assert_equal Time.utc(2000), zone.now.time
          assert_equal zone, zone.now.time_zone
        end
      end
      
      def test_now_enforces_spring_dst_rules
        with_env_tz 'US/Eastern' do
          Time.stubs(:now).returns(Time.local(2006,4,2,2)) # 2AM springs forward to 3AM
          zone = TimeZone['Eastern Time (US & Canada)']
          assert_equal Time.utc(2006,4,2,3), zone.now.time
          assert_equal true, zone.now.dst?
        end
      end
      
      def test_now_enforces_fall_dst_rules
        with_env_tz 'US/Eastern' do
          Time.stubs(:now).returns(Time.at(1162098000)) # equivalent to 1AM DST
          zone = TimeZone['Eastern Time (US & Canada)']
          assert_equal Time.utc(2006,10,29,1), zone.now.time
          assert_equal true, zone.now.dst?
        end
      end
    
      def test_today
        TZInfo::DataTimezone.any_instance.stubs(:now).returns(Time.utc(2000))
        assert_equal Date.new(2000), TimeZone['Eastern Time (US & Canada)'].today
      end
    end
  end
  
  def test_formatted_offset_positive
    zone = TimeZone['Moscow']
    assert_equal "+03:00", zone.formatted_offset
    assert_equal "+0300", zone.formatted_offset(false)
  end
  
  def test_formatted_offset_negative
    zone = TimeZone['Eastern Time (US & Canada)']
    assert_equal "-05:00", zone.formatted_offset
    assert_equal "-0500", zone.formatted_offset(false)
  end
  
  def test_formatted_offset_zero
    zone = TimeZone['London']
    assert_equal "+00:00", zone.formatted_offset
    assert_equal "UTC", zone.formatted_offset(true, 'UTC')
  end
  
  def test_zone_compare
    zone1 = TimeZone['Central Time (US & Canada)'] # offset -0600
    zone2 = TimeZone['Eastern Time (US & Canada)'] # offset -0500
    assert zone1 < zone2
    assert zone2 > zone1
    assert zone1 == zone1
  end
  
  def test_to_s
    assert_equal "(UTC+03:00) Moscow", TimeZone['Moscow'].to_s
  end
  
  def test_all_sorted
    all = TimeZone.all
    1.upto( all.length-1 ) do |i|
      assert all[i-1] < all[i]
    end
  end
  
  def test_index
    assert_nil TimeZone["bogus"]
    assert_instance_of TimeZone, TimeZone["Central Time (US & Canada)"]
    assert_instance_of TimeZone, TimeZone[8]
    assert_raises(ArgumentError) { TimeZone[false] }
  end
  
  def test_new
    assert_equal TimeZone["Central Time (US & Canada)"], TimeZone.new("Central Time (US & Canada)")
  end
  
  def test_us_zones
    assert TimeZone.us_zones.include?(TimeZone["Hawaii"])
    assert !TimeZone.us_zones.include?(TimeZone["Kuala Lumpur"])
  end 
  
  def test_local
    time = TimeZone["Hawaii"].local(2007, 2, 5, 15, 30, 45)
    assert_equal Time.utc(2007, 2, 5, 15, 30, 45), time.time
    assert_equal TimeZone["Hawaii"], time.time_zone
  end
  
  def test_local_enforces_spring_dst_rules
    zone = TimeZone['Eastern Time (US & Canada)']
    twz = zone.local(2006,4,2,1,59,59) # 1 second before DST start
    assert_equal Time.utc(2006,4,2,1,59,59), twz.time
    assert_equal Time.utc(2006,4,2,6,59,59), twz.utc
    assert_equal false, twz.dst?
    assert_equal 'EST', twz.zone
    twz2 = zone.local(2006,4,2,2) # 2AM does not exist because at 2AM, time springs forward to 3AM
    assert_equal Time.utc(2006,4,2,3), twz2.time # twz is created for 3AM
    assert_equal Time.utc(2006,4,2,7), twz2.utc
    assert_equal true, twz2.dst?
    assert_equal 'EDT', twz2.zone
    twz3 = zone.local(2006,4,2,2,30) # 2:30AM does not exist because at 2AM, time springs forward to 3AM
    assert_equal Time.utc(2006,4,2,3,30), twz3.time # twz is created for 3:30AM
    assert_equal Time.utc(2006,4,2,7,30), twz3.utc
    assert_equal true, twz3.dst?
    assert_equal 'EDT', twz3.zone
  end
  
  def test_local_enforces_fall_dst_rules
    # 1AM during fall DST transition is ambiguous, it could be either DST or non-DST 1AM
    # Mirroring Time.local behavior, this method selects the DST time
    zone = TimeZone['Eastern Time (US & Canada)']
    twz = zone.local(2006,10,29,1)
    assert_equal Time.utc(2006,10,29,1), twz.time
    assert_equal Time.utc(2006,10,29,5), twz.utc
    assert_equal true, twz.dst? 
    assert_equal 'EDT', twz.zone
  end

  protected
    def with_env_tz(new_tz = 'US/Eastern')
      old_tz, ENV['TZ'] = ENV['TZ'], new_tz
      yield
    ensure
      old_tz ? ENV['TZ'] = old_tz : ENV.delete('TZ')
    end  
end
