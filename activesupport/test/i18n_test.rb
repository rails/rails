require 'abstract_unit'

class I18nTest < Test::Unit::TestCase
  def setup
    @date = Date.parse("2008-7-2")
    @time = Time.utc(2008, 7, 2, 16, 47, 1)
  end
  
  uses_mocha 'I18nTimeZoneTest' do
    def test_time_zone_localization_with_default_format
      Time.zone.stubs(:now).returns Time.local(2000)
      assert_equal Time.zone.now.strftime("%a, %d %b %Y %H:%M:%S %z"), I18n.localize(Time.zone.now)
    end
  end
  
  def test_date_localization_should_use_default_format
    assert_equal @date.strftime("%Y-%m-%d"), I18n.localize(@date)
  end
  
  def test_date_localization_with_default_format
    assert_equal @date.strftime("%Y-%m-%d"), I18n.localize(@date, :format => :default)
  end
  
  def test_date_localization_with_short_format
    assert_equal @date.strftime("%b %d"), I18n.localize(@date, :format => :short)
  end
  
  def test_date_localization_with_long_format
    assert_equal @date.strftime("%B %d, %Y"), I18n.localize(@date, :format => :long)
  end
  
  def test_time_localization_should_use_default_format    
    assert_equal @time.strftime("%a, %d %b %Y %H:%M:%S %z"), I18n.localize(@time)
  end
  
  def test_time_localization_with_default_format
    assert_equal @time.strftime("%a, %d %b %Y %H:%M:%S %z"), I18n.localize(@time, :format => :default)
  end
  
  def test_time_localization_with_short_format
    assert_equal @time.strftime("%d %b %H:%M"), I18n.localize(@time, :format => :short)
  end
  
  def test_time_localization_with_long_format
    assert_equal @time.strftime("%B %d, %Y %H:%M"), I18n.localize(@time, :format => :long)
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

  def test_sentence_connector
    assert_equal 'and', I18n.translate(:'support.array.sentence_connector')
  end

  def test_skip_last_comma
    assert_equal false, I18n.translate(:'support.array.skip_last_comma')
  end

  def test_to_sentence
    assert_equal 'a, b, and c', %w[a b c].to_sentence
    I18n.backend.store_translations 'en', :support => { :array => { :skip_last_comma => true } }
    assert_equal 'a, b and c', %w[a b c].to_sentence
  ensure
    I18n.backend.store_translations 'en', :support => { :array => { :skip_last_comma => false } }
  end
end
