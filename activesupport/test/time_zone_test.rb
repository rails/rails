require 'abstract_unit'

class TimeZoneTest < Test::Unit::TestCase
  def test_utc_to_local
    silence_warnings do # silence warnings raised by tzinfo gem
      zone = ActiveSupport::TimeZone['Eastern Time (US & Canada)']
      assert_equal Time.utc(1999, 12, 31, 19), zone.utc_to_local(Time.utc(2000, 1)) # standard offset -0500
      assert_equal Time.utc(2000, 6, 30, 20), zone.utc_to_local(Time.utc(2000, 7)) # dst offset -0400
    end
  end

  def test_local_to_utc
    silence_warnings do # silence warnings raised by tzinfo gem
      zone = ActiveSupport::TimeZone['Eastern Time (US & Canada)']
      assert_equal Time.utc(2000, 1, 1, 5), zone.local_to_utc(Time.utc(2000, 1)) # standard offset -0500
      assert_equal Time.utc(2000, 7, 1, 4), zone.local_to_utc(Time.utc(2000, 7)) # dst offset -0400
    end
  end

  def test_period_for_local
    silence_warnings do # silence warnings raised by tzinfo gem
      zone = ActiveSupport::TimeZone['Eastern Time (US & Canada)']
      assert_instance_of TZInfo::TimezonePeriod, zone.period_for_local(Time.utc(2000))
    end
  end

  ActiveSupport::TimeZone::MAPPING.keys.each do |name|
    define_method("test_map_#{name.downcase.gsub(/[^a-z]/, '_')}_to_tzinfo") do
      silence_warnings do # silence warnings raised by tzinfo gem
        zone = ActiveSupport::TimeZone[name]
        assert zone.tzinfo.respond_to?(:period_for_local)
      end
    end
  end

  def test_from_integer_to_map
    assert_instance_of ActiveSupport::TimeZone, ActiveSupport::TimeZone[-28800] # PST
  end

  def test_from_duration_to_map
    assert_instance_of ActiveSupport::TimeZone, ActiveSupport::TimeZone[-480.minutes] # PST
  end

  ActiveSupport::TimeZone.all.each do |zone|
    name = zone.name.downcase.gsub(/[^a-z]/, '_')
    define_method("test_from_#{name}_to_map") do
      silence_warnings do # silence warnings raised by tzinfo gem
        assert_instance_of ActiveSupport::TimeZone, ActiveSupport::TimeZone[zone.name]
      end
    end

    define_method("test_utc_offset_for_#{name}") do
      silence_warnings do # silence warnings raised by tzinfo gem
        period = zone.tzinfo.period_for_utc(Time.utc(2009,1,1,0,0,0))
        assert_equal period.utc_offset, zone.utc_offset
      end
    end
  end

  uses_mocha 'TestTimeZoneNowAndToday' do
    def test_now
      with_env_tz 'US/Eastern' do
        Time.stubs(:now).returns(Time.local(2000))
        zone = ActiveSupport::TimeZone['Eastern Time (US & Canada)']
        assert_instance_of ActiveSupport::TimeWithZone, zone.now
        assert_equal Time.utc(2000,1,1,5), zone.now.utc
        assert_equal Time.utc(2000), zone.now.time
        assert_equal zone, zone.now.time_zone
      end
    end

    def test_now_enforces_spring_dst_rules
      with_env_tz 'US/Eastern' do
        Time.stubs(:now).returns(Time.local(2006,4,2,2)) # 2AM springs forward to 3AM
        zone = ActiveSupport::TimeZone['Eastern Time (US & Canada)']
        assert_equal Time.utc(2006,4,2,3), zone.now.time
        assert_equal true, zone.now.dst?
      end
    end

    def test_now_enforces_fall_dst_rules
      with_env_tz 'US/Eastern' do
        Time.stubs(:now).returns(Time.at(1162098000)) # equivalent to 1AM DST
        zone = ActiveSupport::TimeZone['Eastern Time (US & Canada)']
        assert_equal Time.utc(2006,10,29,1), zone.now.time
        assert_equal true, zone.now.dst?
      end
    end

    def test_today
      Time.stubs(:now).returns(Time.utc(2000, 1, 1, 4, 59, 59)) # 1 sec before midnight Jan 1 EST
      assert_equal Date.new(1999, 12, 31), ActiveSupport::TimeZone['Eastern Time (US & Canada)'].today
      Time.stubs(:now).returns(Time.utc(2000, 1, 1, 5)) # midnight Jan 1 EST
      assert_equal Date.new(2000, 1, 1), ActiveSupport::TimeZone['Eastern Time (US & Canada)'].today
      Time.stubs(:now).returns(Time.utc(2000, 1, 2, 4, 59, 59)) # 1 sec before midnight Jan 2 EST
      assert_equal Date.new(2000, 1, 1), ActiveSupport::TimeZone['Eastern Time (US & Canada)'].today
      Time.stubs(:now).returns(Time.utc(2000, 1, 2, 5)) # midnight Jan 2 EST
      assert_equal Date.new(2000, 1, 2), ActiveSupport::TimeZone['Eastern Time (US & Canada)'].today
    end
  end

  def test_local
    silence_warnings do # silence warnings raised by tzinfo gem
      time = ActiveSupport::TimeZone["Hawaii"].local(2007, 2, 5, 15, 30, 45)
      assert_equal Time.utc(2007, 2, 5, 15, 30, 45), time.time
      assert_equal ActiveSupport::TimeZone["Hawaii"], time.time_zone
    end
  end

  def test_local_with_old_date
    silence_warnings do # silence warnings raised by tzinfo gem
      time = ActiveSupport::TimeZone["Hawaii"].local(1850, 2, 5, 15, 30, 45)
      assert_equal [45,30,15,5,2,1850], time.to_a[0,6]
      assert_equal ActiveSupport::TimeZone["Hawaii"], time.time_zone
    end
  end

  def test_local_enforces_spring_dst_rules
    zone = ActiveSupport::TimeZone['Eastern Time (US & Canada)']
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
    zone = ActiveSupport::TimeZone['Eastern Time (US & Canada)']
    twz = zone.local(2006,10,29,1)
    assert_equal Time.utc(2006,10,29,1), twz.time
    assert_equal Time.utc(2006,10,29,5), twz.utc
    assert_equal true, twz.dst?
    assert_equal 'EDT', twz.zone
  end

  def test_at
    zone = ActiveSupport::TimeZone['Eastern Time (US & Canada)']
    secs = 946684800.0
    twz = zone.at(secs)
    assert_equal Time.utc(1999,12,31,19), twz.time
    assert_equal Time.utc(2000), twz.utc
    assert_equal zone, twz.time_zone
    assert_equal secs, twz.to_f
  end

  def test_at_with_old_date
    zone = ActiveSupport::TimeZone['Eastern Time (US & Canada)']
    secs = DateTime.civil(1850).to_f
    twz = zone.at(secs)
    assert_equal [1850, 1, 1, 0], [twz.utc.year, twz.utc.mon, twz.utc.day, twz.utc.hour]
    assert_equal zone, twz.time_zone
    assert_equal secs, twz.to_f
  end

  def test_parse
    zone = ActiveSupport::TimeZone['Eastern Time (US & Canada)']
    twz = zone.parse('1999-12-31 19:00:00')
    assert_equal Time.utc(1999,12,31,19), twz.time
    assert_equal Time.utc(2000), twz.utc
    assert_equal zone, twz.time_zone
  end

  def test_parse_string_with_timezone
    (-11..13).each do |timezone_offset|
      zone = ActiveSupport::TimeZone[timezone_offset]
      twz = zone.parse('1999-12-31 19:00:00')
      assert_equal twz, zone.parse(twz.to_s)
    end
  end

  def test_parse_with_old_date
    silence_warnings do # silence warnings raised by tzinfo gem
      zone = ActiveSupport::TimeZone['Eastern Time (US & Canada)']
      twz = zone.parse('1850-12-31 19:00:00')
      assert_equal [0,0,19,31,12,1850], twz.to_a[0,6]
      assert_equal zone, twz.time_zone
    end
  end

  def test_parse_far_future_date_with_time_zone_offset_in_string
    silence_warnings do # silence warnings raised by tzinfo gem
      zone = ActiveSupport::TimeZone['Eastern Time (US & Canada)']
      twz = zone.parse('2050-12-31 19:00:00 -10:00') # i.e., 2050-01-01 05:00:00 UTC
      assert_equal [0,0,0,1,1,2051], twz.to_a[0,6]
      assert_equal zone, twz.time_zone
    end
  end

  def test_parse_returns_nil_when_string_without_date_information_is_passed_in
    silence_warnings do # silence warnings raised by tzinfo gem
      zone = ActiveSupport::TimeZone['Eastern Time (US & Canada)']
      assert_nil zone.parse('foobar')
      assert_nil zone.parse('   ')
    end
  end

  uses_mocha 'TestParseWithIncompleteDate' do
    def test_parse_with_incomplete_date
      zone = ActiveSupport::TimeZone['Eastern Time (US & Canada)']
      zone.stubs(:now).returns zone.local(1999,12,31)
      twz = zone.parse('19:00:00')
      assert_equal Time.utc(1999,12,31,19), twz.time
    end
  end

  def test_utc_offset_lazy_loaded_from_tzinfo_when_not_passed_in_to_initialize
    silence_warnings do # silence warnings raised by tzinfo gem
      tzinfo = TZInfo::Timezone.get('America/New_York')
      zone = ActiveSupport::TimeZone.create(tzinfo.name, nil, tzinfo)
      assert_equal nil, zone.instance_variable_get('@utc_offset')
      assert_equal(-18_000, zone.utc_offset)
    end
  end

  def test_formatted_offset_positive
    zone = ActiveSupport::TimeZone['Moscow']
    assert_equal "+03:00", zone.formatted_offset
    assert_equal "+0300", zone.formatted_offset(false)
  end

  def test_formatted_offset_negative
    zone = ActiveSupport::TimeZone['Eastern Time (US & Canada)']
    assert_equal "-05:00", zone.formatted_offset
    assert_equal "-0500", zone.formatted_offset(false)
  end

  def test_formatted_offset_zero
    zone = ActiveSupport::TimeZone['London']
    assert_equal "+00:00", zone.formatted_offset
    assert_equal "UTC", zone.formatted_offset(true, 'UTC')
  end

  def test_zone_compare
    zone1 = ActiveSupport::TimeZone['Central Time (US & Canada)'] # offset -0600
    zone2 = ActiveSupport::TimeZone['Eastern Time (US & Canada)'] # offset -0500
    assert zone1 < zone2
    assert zone2 > zone1
    assert zone1 == zone1
  end

  def test_zone_match
    zone = ActiveSupport::TimeZone['Eastern Time (US & Canada)']
    assert zone =~ /Eastern/
    assert zone =~ /New_York/
    assert zone !~ /Nonexistent_Place/
  end

  def test_to_s
    assert_equal "(GMT+03:00) Moscow", ActiveSupport::TimeZone['Moscow'].to_s
  end

  def test_all_sorted
    all = ActiveSupport::TimeZone.all
    1.upto( all.length-1 ) do |i|
      assert all[i-1] < all[i]
    end
  end

  def test_index
    assert_nil ActiveSupport::TimeZone["bogus"]
    assert_instance_of ActiveSupport::TimeZone, ActiveSupport::TimeZone["Central Time (US & Canada)"]
    assert_instance_of ActiveSupport::TimeZone, ActiveSupport::TimeZone[8]
    assert_raises(ArgumentError) { ActiveSupport::TimeZone[false] }
  end

  def test_new
    assert_equal ActiveSupport::TimeZone["Central Time (US & Canada)"], ActiveSupport::TimeZone.new("Central Time (US & Canada)")
  end

  def test_us_zones
    assert ActiveSupport::TimeZone.us_zones.include?(ActiveSupport::TimeZone["Hawaii"])
    assert !ActiveSupport::TimeZone.us_zones.include?(ActiveSupport::TimeZone["Kuala Lumpur"])
  end

  protected
    def with_env_tz(new_tz = 'US/Eastern')
      old_tz, ENV['TZ'] = ENV['TZ'], new_tz
      yield
    ensure
      old_tz ? ENV['TZ'] = old_tz : ENV.delete('TZ')
    end
end
