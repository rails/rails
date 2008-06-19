require 'abstract_unit'
require 'action_view/helpers/i18n_helper'

class I18nHelperTests < Test::Unit::TestCase
  include ActionView::Helpers::I18nHelper
  
  attr_reader :request
  def setup
    @request = stub :locale => 'en-US'
    I18n.stubs(:translate).with(:'foo.bar', 'en-US').returns 'Foo Bar'
  end

  def test_translate_given_a_locale_argument_it_does_not_check_request_for_locale
    request.expects(:locale).never
    assert_equal 'Foo Bar', translate(:'foo.bar', :locale => 'en-US')
  end

  def test_translate_given_a_locale_option_it_does_not_check_request_for_locale
    request.expects(:locale).never
    I18n.expects(:translate).with(:'foo.bar', 'en-US').returns 'Foo Bar'
    assert_equal 'Foo Bar', translate(:'foo.bar', :locale => 'en-US')
  end
  
  def test_translate_given_no_locale_it_checks_request_for_locale
    request.expects(:locale).returns 'en-US'
    assert_equal 'Foo Bar', translate(:'foo.bar')
  end

  def test_translate_delegates_to_i18n_translate
    I18n.expects(:translate).with(:'foo.bar', 'en-US').returns 'Foo Bar'
    assert_equal 'Foo Bar', translate(:'foo.bar')
  end
end