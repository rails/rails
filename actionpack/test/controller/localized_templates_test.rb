require 'abstract_unit'

class LocalizedController < ActionController::Base
  def hello_world
  end
end

class LocalizedTemplatesTest < ActionController::TestCase
  tests LocalizedController

  def setup
    @i18n_locale = I18n.locale
  end

  def teardown
    I18n.locale = @i18n_locale
  end

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

  def test_use_fallback_locales
    I18n.locale = :"de-AT"
    I18n.backend.class.send(:include, I18n::Backend::Fallbacks)
    I18n.fallbacks[:"de-AT"] = [:de]

    get :hello_world
    assert_equal "Gutten Tag", @response.body
  end
end