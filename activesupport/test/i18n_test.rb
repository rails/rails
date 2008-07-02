require 'abstract_unit'

class I18nTest < Test::Unit::TestCase
  def setup
    @date = Date.parse("2008-7-2")
    @time = Time.utc(2008, 7, 2, 16, 47, 1)
  end
  
  uses_mocha 'I18nTimeZoneTest' do
    def test_time_zone_localization_with_default_format
      Time.zone.stubs(:now).returns Time.local(2000)
      assert_equal "Sat, 01 Jan 2000 00:00:00 +0100", I18n.localize(Time.zone.now)
    end
  end
  
  def test_date_localization_should_use_default_format
    assert_equal "2008-07-02", I18n.localize(@date)
  end
  
  def test_date_localization_with_default_format
    assert_equal "2008-07-02", I18n.localize(@date, nil, :default)
  end
  
  def test_date_localization_with_short_format
    assert_equal "Jul 02", I18n.localize(@date, nil, :short)
  end
  
  def test_date_localization_with_long_format
    assert_equal "July 02, 2008", I18n.localize(@date, nil, :long)
  end
  
  def test_time_localization_should_use_default_format
    assert_equal "Wed, 02 Jul 2008 16:47:01 +0100", I18n.localize(@time)
  end
  
  def test_time_localization_with_default_format
    assert_equal "Wed, 02 Jul 2008 16:47:01 +0100", I18n.localize(@time, nil, :default)
  end
  
  def test_time_localization_with_short_format
    assert_equal "02 Jul 16:47", I18n.localize(@time, nil, :short)
  end
  
  def test_time_localization_with_long_format
    assert_equal "July 02, 2008 16:47", I18n.localize(@time, nil, :long)
  end
    
  def test_day_names
    assert_equal Date::DAYNAMES, I18n.translate(:'date.day_names')
  end
  
  def test_abbr_day_names
    assert_equal Date::ABBR_DAYNAMES, I18n.translate(:'date.abbr_day_names')
  end
  
  def test_month_names
    assert_equal Date::MONTHNAMES, I18n.translate(:'date.month_names')
  end
  
  def test_abbr_month_names
    assert_equal Date::ABBR_MONTHNAMES, I18n.translate(:'date.abbr_month_names')
  end
  
  def test_date_order
    assert_equal [:year, :month, :day], I18n.translate(:'date.order')
  end
  
  def test_time_am
    assert_equal 'am', I18n.translate(:'time.am')
  end
  
  def test_time_pm
    assert_equal 'pm', I18n.translate(:'time.pm')
  end
end
