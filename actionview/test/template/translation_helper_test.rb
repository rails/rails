require 'abstract_unit'

module I18n
  class CustomExceptionHandler
    def self.call(exception, locale, key, options)
      'from CustomExceptionHandler'
    end
  end
end

class TranslationHelperTest < ActiveSupport::TestCase
  include ActionView::Helpers::TranslationHelper

  attr_reader :request, :view

  def setup
    I18n.backend.store_translations(:en,
      :translations => {
        :templates => {
          :found => { :foo => 'Foo' },
          :array => { :foo => { :bar => 'Foo Bar' } },
          :default => { :foo => 'Foo' }
        },
        :foo => 'Foo',
        :hello => '<a>Hello World</a>',
        :html => '<a>Hello World</a>',
        :hello_html => '<a>Hello World</a>',
        :interpolated_html => '<a>Hello %{word}</a>',
        :array_html => %w(foo bar),
        :array => %w(foo bar),
        :count_html => {
          :one   => '<a>One %{count}</a>',
          :other => '<a>Other %{count}</a>'
        }
      }
    )
    @view = ::ActionView::Base.new(ActionController::Base.view_paths, {})
  end

  def test_delegates_to_i18n_setting_the_rescue_format_option_to_html
    I18n.expects(:translate).with(:foo, :locale => 'en', :raise=>true).returns("")
    translate :foo, :locale => 'en'
  end

  def test_delegates_localize_to_i18n
    @time = Time.utc(2008, 7, 8, 12, 18, 38)
    I18n.expects(:localize).with(@time)
    localize @time
  end

  def test_returns_missing_translation_message_wrapped_into_span
    expected = '<span class="translation_missing" title="translation missing: en.translations.missing">Missing</span>'
    assert_equal expected, translate(:"translations.missing")
    assert_equal true, translate(:"translations.missing").html_safe?
  end

  def test_returns_missing_translation_message_using_nil_as_rescue_format
    expected = 'translation missing: en.translations.missing'
    assert_equal expected, translate(:"translations.missing", :rescue_format => nil)
    assert_equal false, translate(:"translations.missing", :rescue_format => nil).html_safe?
  end

  def test_raises_missing_translation_message_with_raise_config_option
    ActionView::Base.raise_on_missing_translations = true

    assert_raise(I18n::MissingTranslationData) do
      translate("translations.missing")
    end
  ensure
    ActionView::Base.raise_on_missing_translations = false
  end

  def test_raises_missing_translation_message_with_raise_option
    assert_raise(I18n::MissingTranslationData) do
      translate(:"translations.missing", :raise => true)
    end
  end

  def test_uses_custom_exception_handler_when_specified
    old_exception_handler = I18n.exception_handler
    I18n.exception_handler = I18n::CustomExceptionHandler
    assert_equal 'from CustomExceptionHandler', translate(:"translations.missing", raise: false)
  ensure
    I18n.exception_handler = old_exception_handler
  end

  def test_uses_custom_exception_handler_when_specified_for_html
    old_exception_handler = I18n.exception_handler
    I18n.exception_handler = I18n::CustomExceptionHandler
    assert_equal 'from CustomExceptionHandler', translate(:"translations.missing_html", raise: false)
  ensure
    I18n.exception_handler = old_exception_handler
  end

  def test_i18n_translate_defaults_to_nil_rescue_format
    expected = 'translation missing: en.translations.missing'
    assert_equal expected, I18n.translate(:"translations.missing")
    assert_equal false, I18n.translate(:"translations.missing").html_safe?
  end

  def test_translation_returning_an_array
    expected = %w(foo bar)
    assert_equal expected, translate(:"translations.array")
  end

  def test_finds_translation_scoped_by_partial
    assert_equal 'Foo', view.render(:file => 'translations/templates/found').strip
  end

  def test_finds_array_of_translations_scoped_by_partial
    assert_equal 'Foo Bar', @view.render(:file => 'translations/templates/array').strip
  end

  def test_default_lookup_scoped_by_partial
    assert_equal 'Foo', view.render(:file => 'translations/templates/default').strip
  end

  def test_missing_translation_scoped_by_partial
    expected = '<span class="translation_missing" title="translation missing: en.translations.templates.missing.missing">Missing</span>'
    assert_equal expected, view.render(:file => 'translations/templates/missing').strip
  end

  def test_translate_does_not_mark_plain_text_as_safe_html
    assert_equal false, translate(:'translations.hello').html_safe?
  end

  def test_translate_marks_translations_named_html_as_safe_html
    assert translate(:'translations.html').html_safe?
  end

  def test_translate_marks_translations_with_a_html_suffix_as_safe_html
    assert translate(:'translations.hello_html').html_safe?
  end

  def test_translate_escapes_interpolations_in_translations_with_a_html_suffix
    assert_equal '<a>Hello &lt;World&gt;</a>', translate(:'translations.interpolated_html', :word => '<World>')
    assert_equal '<a>Hello &lt;World&gt;</a>', translate(:'translations.interpolated_html', :word => stub(:to_s => "<World>"))
  end

  def test_translate_with_html_count
    assert_equal '<a>One 1</a>', translate(:'translations.count_html', :count => 1)
    assert_equal '<a>Other 2</a>', translate(:'translations.count_html', :count => 2)
    assert_equal '<a>Other &lt;One&gt;</a>', translate(:'translations.count_html', :count => '<One>')
  end

  def test_translation_returning_an_array_ignores_html_suffix
    assert_equal ["foo", "bar"], translate(:'translations.array_html')
  end

  def test_translate_with_default_named_html
    translation = translate(:'translations.missing', :default => :'translations.hello_html')
    assert_equal '<a>Hello World</a>', translation
    assert_equal true, translation.html_safe?
  end

  def test_translate_with_missing_default
    translation = translate(:'translations.missing', :default => :'translations.missing_html')
    expected = '<span class="translation_missing" title="translation missing: en.translations.missing_html">Missing Html</span>'
    assert_equal expected, translation
    assert_equal true, translation.html_safe?
  end

  def test_translate_with_missing_default_and_raise_option
    assert_raise(I18n::MissingTranslationData) do
      translate(:'translations.missing', :default => :'translations.missing_html', :raise => true)
    end
  end

  def test_translate_with_two_defaults_named_html
    translation = translate(:'translations.missing', :default => [:'translations.missing_html', :'translations.hello_html'])
    assert_equal '<a>Hello World</a>', translation
    assert_equal true, translation.html_safe?
  end

  def test_translate_with_last_default_named_html
    translation = translate(:'translations.missing', :default => [:'translations.missing', :'translations.hello_html'])
    assert_equal '<a>Hello World</a>', translation
    assert_equal true, translation.html_safe?
  end

  def test_translate_with_last_default_not_named_html
    translation = translate(:'translations.missing', :default => [:'translations.missing_html', :'translations.foo'])
    assert_equal 'Foo', translation
    assert_equal false, translation.html_safe?
  end

  def test_translate_with_string_default
    translation = translate(:'translations.missing', default: 'A Generic String')
    assert_equal 'A Generic String', translation
  end

  def test_translate_with_object_default
    translation = translate(:'translations.missing', default: 123)
    assert_equal 123, translation
  end

  def test_translate_with_array_of_string_defaults
    translation = translate(:'translations.missing', default: ['A Generic String', 'Second generic string'])
    assert_equal 'A Generic String', translation
  end

  def test_translate_with_array_of_defaults_with_nil
    translation = translate(:'translations.missing', default: [:'also_missing', nil, 'A Generic String'])
    assert_equal 'A Generic String', translation
  end
end
