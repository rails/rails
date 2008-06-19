require 'abstract_unit'

class FormOptionsHelperI18nTests < Test::Unit::TestCase
  include ActionView::Helpers::FormOptionsHelper
  attr_reader :request
  
  def setup
    @request = mock
  end

  def test_country_options_for_select_given_a_locale_it_does_not_check_request_for_locale
    request.expects(:locale).never
    country_options_for_select :locale => 'en-US'
  end
  
  def test_country_options_for_select_given_no_locale_it_checks_request_for_locale
    request.expects(:locale).returns 'en-US'
    country_options_for_select
  end

  def test_country_options_for_select_translates_country_names
    countries = ActionView::Helpers::FormOptionsHelper::COUNTRIES
    I18n.expects(:translate).with(:'countries.names', 'en-US').returns countries
    country_options_for_select :locale => 'en-US'
  end  
end