require 'abstract_unit'

class I18nTest < Test::Unit::TestCase
  def setup
    @date = Date.parse("2008-7-2")
    @time = Time.utc(2008, 7, 2, 16, 47, 1)
  end
  
  uses_mocha 'I18nTimeZoneTest' do
    def test_time_zone_localization_with_default_format
      Time.zone.stubs(:now).returns Time.local(2000)
      assert_equal "Sat, 01 Jan 2000 00:00:00 +0100", Time.zone.now.l
    end
  end
  
  def test_date_localization_should_use_default_format
    assert_equal "2008-07-02", @date.l
  end
  
  def test_date_localization_with_default_format
    assert_equal "2008-07-02", @date.l(nil, :default)
  end
  
  def test_date_localization_with_short_format
    assert_equal "Jul 02", @date.l(nil, :short)
  end
  
  def test_date_localization_with_long_format
    assert_equal "July 02, 2008", @date.l(nil, :long)
  end
  
  def test_time_localization_should_use_default_format
    assert_equal "Wed, 02 Jul 2008 16:47:01 +0100", @time.l
  end
  
  def test_time_localization_with_default_format
    assert_equal "Wed, 02 Jul 2008 16:47:01 +0100", @time.l(nil, :default)
  end
  
  def test_time_localization_with_short_format
    assert_equal "02 Jul 16:47", @time.l(nil, :short)
  end
  
  def test_time_localization_with_long_format
    assert_equal "July 02, 2008 16:47", @time.l(nil, :long)
  end
    
  def test_day_names
    assert_equal Date::DAYNAMES, :'date.day_names'.t
  end
  
  def test_abbr_day_names
    assert_equal Date::ABBR_DAYNAMES, :'date.abbr_day_names'.t
  end
  
  def test_month_names
    assert_equal Date::MONTHNAMES, :'date.month_names'.t
  end
  
  def test_abbr_month_names
    assert_equal Date::ABBR_MONTHNAMES, :'date.abbr_month_names'.t
  end
  
  def test_date_order
    assert_equal [:year, :month, :day], :'date.order'.t
  end
  
  def test_time_am
    assert_equal 'am', :'time.am'.t
  end
  
  def test_time_pm
    assert_equal 'pm', :'time.pm'.t
  end
end
