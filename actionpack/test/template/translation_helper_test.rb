require 'abstract_unit'

class TranslationHelperTest < ActiveSupport::TestCase
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::TranslationHelper

  attr_reader :request
  def setup
  end

  def test_delegates_to_i18n_setting_the_raise_option
    I18n.expects(:translate).with(:foo, :locale => 'en', :raise => true).returns("")
    translate :foo, :locale => 'en'
  end

  def test_returns_missing_translation_message_wrapped_into_span
    expected = '<span class="translation_missing">en, foo</span>'
    assert_equal expected, translate(:foo)
  end

  def test_translation_returning_an_array
    I18n.expects(:translate).with(:foo, :raise => true).returns(["foo", "bar"])
    assert_equal ["foo", "bar"], translate(:foo)
  end

  def test_delegates_localize_to_i18n
    @time = Time.utc(2008, 7, 8, 12, 18, 38)
    I18n.expects(:localize).with(@time)
    localize @time
  end

  def test_scoping_by_partial
    I18n.expects(:translate).with("test.translation.helper", :raise => true).returns("helper")
    @view = ActionView::Base.new(ActionController::Base.view_paths, {})
    assert_equal "helper", @view.render(:file => "test/translation")
  end

  def test_scoping_by_partial_of_an_array
    I18n.expects(:translate).with("test.scoped_translation.foo.bar", :raise => true).returns(["foo", "bar"])
    @view = ActionView::Base.new(ActionController::Base.view_paths, {})
    assert_equal "foobar", @view.render(:file => "test/scoped_translation")
  end

  def test_translate_does_not_mark_plain_text_as_safe_html
    I18n.expects(:translate).with("hello", :raise => true).returns("Hello World")
    assert_equal false, translate("hello").html_safe?
  end

  def test_translate_marks_translations_named_html_as_safe_html
    I18n.expects(:translate).with("html", :raise => true).returns("<a>Hello World</a>")
    assert translate("html").html_safe?
  end

  def test_translate_marks_translations_with_a_html_suffix_as_safe_html
    I18n.expects(:translate).with("hello_html", :raise => true).returns("<a>Hello World</a>")
    assert translate("hello_html").html_safe?
  end

  def test_translation_returning_an_array_ignores_html_suffix
    I18n.expects(:translate).with(:foo_html, :raise => true).returns(["foo", "bar"])
    assert_equal ["foo", "bar"], translate(:foo_html)
  end
end
