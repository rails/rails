require 'abstract_unit'

class NumberHelperI18nTests < Test::Unit::TestCase
  include ActionView::Helpers::NumberHelper
  
  attr_reader :request
  def setup
    stubs(:locale)
    @defaults = {:separator => ".", :unit => "$", :format => "%u%n", :delimiter => ",", :precision => 2}
    I18n.backend.store_translations 'en-US', :currency => {:format => @defaults}
  end

  def test_number_to_currency_given_a_locale_it_does_not_check_request_for_locale
    expects(:locale).never
    number_to_currency(1, :locale => 'en-US')
  end

  def test_number_to_currency_given_no_locale_it_checks_request_for_locale
    expects(:locale).returns 'en-US'
    number_to_currency(1)
  end

  def test_number_to_currency_translates_currency_formats
    I18n.expects(:translate).with(:'currency.format', 'en-US').returns @defaults
    number_to_currency(1, :locale => 'en-US')
  end
end