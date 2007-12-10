require File.dirname(__FILE__) + '/abstract_unit'

class TimeZoneTest < Test::Unit::TestCase
  class MockTime
    def self.now
      Time.utc( 2004, 7, 25, 14, 49, 00 )
    end

    def self.local(*args)
      Time.utc(*args)
    end
  end

  TimeZone::Time = MockTime

  def test_formatted_offset_positive
    zone = TimeZone.create( "Test", 4200 )
    assert_equal "+01:10", zone.formatted_offset
  end

  def test_formatted_offset_negative
    zone = TimeZone.create( "Test", -4200 )
    assert_equal "-01:10", zone.formatted_offset
  end

  def test_now
    zone = TimeZone.create( "Test", 4200 )
    assert_equal Time.local(2004,7,25,15,59,00).to_a[0,6], zone.now.to_a[0,6]
  end

  def test_today
    zone = TimeZone.create( "Test", 43200 )
    assert_equal Date.new(2004,7,26), zone.today
  end

  def test_adjust_negative
    zone = TimeZone.create( "Test", -4200 ) # 4200s == 70 mins
    assert_equal Time.utc(2004,7,24,23,55,0), zone.adjust(Time.utc(2004,7,25,1,5,0))
  end

  def test_adjust_positive
    zone = TimeZone.create( "Test", 4200 )
    assert_equal Time.utc(2004,7,26,1,5,0), zone.adjust(Time.utc(2004,7,25,23,55,0))
  end

  def test_unadjust
    zone = TimeZone.create( "Test", 4200 )
    expect = Time.utc(2004,7,24,23,55,0).to_a[0,6]
    actual = zone.unadjust(Time.utc(2004,7,25,1,5,0)).to_a[0,6]
    assert_equal expect, actual
  end

  def test_zone_compare
    zone1 = TimeZone.create( "Test1", 4200 )
    zone2 = TimeZone.create( "Test1", 5600 )
    assert zone1 < zone2
    assert zone2 > zone1

    zone1 = TimeZone.create( "Able", 10000 )
    zone2 = TimeZone.create( "Zone", 10000 )
    assert zone1 < zone2
    assert zone2 > zone1

    zone1 = TimeZone.create( "Able", 10000 )
    assert zone1 == zone1
  end

  def test_to_s
    zone = TimeZone.create( "Test", 4200 )
    assert_equal "(UTC+01:10) Test", zone.to_s
  end

  def test_all_sorted
    all = TimeZone.all
    1.upto( all.length-1 ) do |i|
      assert all[i-1] < all[i]
    end
  end

  def test_index
    assert_nil TimeZone["bogus"]
    assert_not_nil TimeZone["Central Time (US & Canada)"]
    assert_not_nil TimeZone[8]
    assert_raises(ArgumentError) { TimeZone[false] }
  end
  
  def test_new
    a = TimeZone.new("Berlin")
    b = TimeZone.new("Berlin")
    assert_same a, b
    assert_nil TimeZone.new("bogus")
  end
  
  def test_us_zones
    assert TimeZone.us_zones.include?(TimeZone["Hawaii"])
    assert !TimeZone.us_zones.include?(TimeZone["Kuala Lumpur"])
  end 
end
