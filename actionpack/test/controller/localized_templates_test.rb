# frozen_string_literal: true

require "abstract_unit"

class LocalizedController < ActionController::Base
  def hello_world
  end
end

class LocalizedTemplatesTest < ActionController::TestCase
  tests LocalizedController

  setup do
    @old_locale = I18n.locale
  end

  teardown do
    I18n.locale = @old_locale
  end

  def test_localized_template_is_used
    I18n.locale = :de
    get :hello_world
    assert_equal "Guten Tag", @response.body
  end

  def test_default_locale_template_is_used_when_locale_is_missing
    I18n.locale = :dk
    get :hello_world
    assert_equal "Hello World", @response.body
  end

  def test_use_fallback_locales
    I18n.locale = :"de-AT"
    I18n.backend.class.include(I18n::Backend::Fallbacks)
    I18n.fallbacks[:"de-AT"] = [:de]

    get :hello_world
    assert_equal "Guten Tag", @response.body
  end

  def test_localized_template_has_correct_header_with_no_format_in_template_name
    I18n.locale = :it
    get :hello_world
    assert_equal "Ciao Mondo", @response.body
    assert_equal "text/html",  @response.media_type
  end

  def test_use_locale_with_lowdash
    I18n.locale = :"de_AT"

    get :hello_world
    assert_equal "Guten Morgen", @response.body
  end
end
