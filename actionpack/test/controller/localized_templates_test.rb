require 'abstract_unit'

class LocalizedController < ActionController::Base
  def hello_world
  end
end

class LocalizedTemplatesTest < ActionController::TestCase
  tests LocalizedController

  teardown { I18n.locale = :en }

  def test_localized_template_is_used
    I18n.locale = :de
    get :hello_world
    assert_equal "Gutten Tag", @response.body
  end

  def test_default_locale_template_is_used_when_locale_is_missing
    I18n.locale = :dk
    get :hello_world
    assert_equal "Hello World", @response.body
  end
end