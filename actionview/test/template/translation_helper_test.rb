# frozen_string_literal: true

require "abstract_unit"

module I18n
  class CustomExceptionHandler
    def self.call(exception, locale, key, options)
      "from CustomExceptionHandler"
    end
  end
end

class TranslationHelperTest < ActiveSupport::TestCase
  include ActionView::Helpers::TranslationHelper

  attr_reader :request, :view

  setup do
    I18n.backend.store_translations(:en,
      translations: {
        templates: {
          found: { foo: "Foo" },
          found_yield_single_argument: { foo: "Foo" },
          found_yield_block: { foo: "Foo" },
          array: { foo: { bar: "Foo Bar" } },
          default: { foo: "Foo" },
          translate_in_layout: { foo: "Foo" },
        },
        foo: "Foo",
        hello: "<a>Hello World</a>",
        html: "<a>Hello World</a>",
        hello_html: "<a>Hello World</a>",
        interpolated_html: "<a>Hello %{word}</a>",
        array_html: %w(foo bar),
        array: %w(foo bar),
        count_html: {
          one: "<a>One %{count}</a>",
          other: "<a>Other %{count}</a>"
        }
      }
    )
    view_paths = ActionController::Base.view_paths
    view_paths.each(&:clear_cache)
    ActionView::LookupContext.fallbacks.each(&:clear_cache)
    @view = ::ActionView::Base.with_empty_template_cache.with_view_paths(view_paths, {})
  end

  teardown do
    I18n.backend.reload!
  end

  def test_delegates_setting_to_i18n
    matcher_called = false
    matcher = ->(key, options) do
      matcher_called = true
      assert_equal :foo, key
      assert_equal "en", options[:locale]
    end

    I18n.stub(:translate, matcher) do
      translate :foo, locale: "en"
    end

    assert matcher_called
  end

  def test_delegates_localize_to_i18n
    @time = Time.utc(2008, 7, 8, 12, 18, 38)
    assert_called_with(I18n, :localize, [@time, locale: "en"]) do
      localize @time, locale: "en"
    end
    assert_equal "Tue, 08 Jul 2008 12:18:38 +0000", localize(@time, locale: "en")
  end

  def test_returns_missing_translation_message_without_span_wrap
    old_value = ActionView::Base.debug_missing_translation
    ActionView::Base.debug_missing_translation = false

    expected = "translation missing: en.translations.missing"
    assert_equal expected, translate(:"translations.missing")
  ensure
    ActionView::Base.debug_missing_translation = old_value
  end

  def test_returns_missing_translation_message_wrapped_into_span
    expected = '<span class="translation_missing" title="translation missing: en.translations.missing">Missing</span>'
    assert_equal expected, translate(:"translations.missing")
    assert_equal true, translate(:"translations.missing").html_safe?
  end

  def test_returns_missing_translation_message_with_unescaped_interpolation
    expected = '<span class="translation_missing" title="translation missing: en.translations.missing, name: Kir, year: 2015, vulnerable: &amp;quot; onclick=&amp;quot;alert()&amp;quot;">Missing</span>'
    assert_equal expected, translate(:"translations.missing", name: "Kir", year: "2015", vulnerable: %{" onclick="alert()"})
    assert_predicate translate(:"translations.missing"), :html_safe?
  end

  def test_returns_missing_translation_message_does_filters_out_i18n_options
    expected = '<span class="translation_missing" title="translation missing: en.translations.missing, year: 2015">Missing</span>'
    assert_equal expected, translate(:"translations.missing", year: "2015", default: [])

    expected = '<span class="translation_missing" title="translation missing: en.scoped.translations.missing, year: 2015">Missing</span>'
    assert_equal expected, translate(:"translations.missing", year: "2015", scope: %i(scoped))
  end

  def test_raises_missing_translation_message_with_raise_config_option
    ActionView::Base.raise_on_missing_translations = true

    assert_raise(I18n::MissingTranslationData) do
      translate("translations.missing")
    end
  ensure
    ActionView::Base.raise_on_missing_translations = false
  end

  def test_raise_arg_overrides_raise_config_option
    ActionView::Base.raise_on_missing_translations = true

    expected = "translation missing: en.translations.missing"
    assert_equal expected, translate(:"translations.missing", raise: false)
  ensure
    ActionView::Base.raise_on_missing_translations = false
  end

  def test_raises_missing_translation_message_with_raise_option
    assert_raise(I18n::MissingTranslationData) do
      translate(:"translations.missing", raise: true)
    end
  end

  def test_uses_custom_exception_handler_when_specified
    old_exception_handler = I18n.exception_handler
    I18n.exception_handler = I18n::CustomExceptionHandler
    assert_equal "from CustomExceptionHandler", translate(:"translations.missing", raise: false)
  ensure
    I18n.exception_handler = old_exception_handler
  end

  def test_uses_custom_exception_handler_when_specified_for_html
    old_exception_handler = I18n.exception_handler
    I18n.exception_handler = I18n::CustomExceptionHandler
    assert_equal "from CustomExceptionHandler", translate(:"translations.missing_html", raise: false)
  ensure
    I18n.exception_handler = old_exception_handler
  end

  def test_hash_default
    default = { separator: ".", delimiter: "," }
    assert_equal default, translate(:'special.number.format', default: default)
  end

  def test_translation_returning_an_array
    expected = %w(foo bar)
    assert_equal expected, translate(:"translations.array")
  end

  def test_finds_translation_scoped_by_partial
    assert_equal "Foo", view.render(template: "translations/templates/found").strip
  end

  def test_finds_translation_scoped_by_partial_yielding_single_argument_block
    assert_equal "Foo", view.render(template: "translations/templates/found_yield_single_argument").strip
  end

  def test_finds_translation_scoped_by_partial_yielding_translation_and_key
    assert_equal "translations.templates.found_yield_block.foo: Foo", view.render(template: "translations/templates/found_yield_block").strip
  end

  def test_finds_translation_scoped_by_translate_in_layout
    assert_equal "Foo", view.render(template: "translations/templates/translate_in_layout").strip
  end

  def test_finds_array_of_translations_scoped_by_partial
    assert_equal "Foo Bar", @view.render(template: "translations/templates/array").strip
  end

  def test_default_lookup_scoped_by_partial
    assert_equal "Foo", view.render(template: "translations/templates/default").strip
  end

  def test_missing_translation_scoped_by_partial
    expected = '<span class="translation_missing" title="translation missing: en.translations.templates.missing.missing">Missing</span>'
    assert_equal expected, view.render(template: "translations/templates/missing").strip
  end

  def test_missing_translation_scoped_by_partial_yield_block
    expected = 'translations.templates.missing_yield_block.missing: <span class="translation_missing" title="translation missing: en.translations.templates.missing_yield_block.missing">Missing</span>'
    assert_equal expected, view.render(template: "translations/templates/missing_yield_block").strip
  end

  def test_missing_translation_scoped_by_partial_yield_block_without_debug_wrapper
    old_debug_missing_translation = ActionView::Base.debug_missing_translation
    ActionView::Base.debug_missing_translation = false

    expected = "translations.templates.missing_yield_block.missing: translation missing: en.translations.templates.missing_yield_block.missing"
    assert_equal expected, view.render(template: "translations/templates/missing_yield_block").strip
  ensure
    ActionView::Base.debug_missing_translation = old_debug_missing_translation
  end

  def test_missing_translation_with_default_scoped_by_partial_yield_block
    expected = "translations.templates.missing_with_default_yield_block.missing: Default"
    assert_equal expected, view.render(template: "translations/templates/missing_with_default_yield_block").strip
  end

  def test_missing_translation_scoped_by_partial_yield_single_argument_block
    expected = '<span class="translation_missing" title="translation missing: en.translations.templates.missing_yield_single_argument_block.missing">Missing</span>'
    assert_equal expected, view.render(template: "translations/templates/missing_yield_single_argument_block").strip
  end

  def test_missing_translation_with_default_scoped_by_partial_yield_single_argument_block
    expected = "Default"
    assert_equal expected, view.render(template: "translations/templates/missing_with_default_yield_single_argument_block").strip
  end

  def test_translate_does_not_mark_plain_text_as_safe_html
    assert_equal false, translate(:'translations.hello').html_safe?
  end

  def test_translate_marks_translations_named_html_as_safe_html
    assert_predicate translate(:'translations.html'), :html_safe?
  end

  def test_translate_marks_translations_with_a_html_suffix_as_safe_html
    assert_predicate translate(:'translations.hello_html'), :html_safe?
  end

  def test_translate_escapes_interpolations_in_translations_with_a_html_suffix
    word_struct = Struct.new(:to_s)
    assert_equal "<a>Hello &lt;World&gt;</a>", translate(:'translations.interpolated_html', word: "<World>")
    assert_equal "<a>Hello &lt;World&gt;</a>", translate(:'translations.interpolated_html', word: word_struct.new("<World>"))
  end

  def test_translate_with_html_count
    assert_equal "<a>One 1</a>", translate(:'translations.count_html', count: 1)
    assert_equal "<a>Other 2</a>", translate(:'translations.count_html', count: 2)
    assert_equal "<a>Other &lt;One&gt;</a>", translate(:'translations.count_html', count: "<One>")
  end

  def test_translate_marks_array_of_translations_with_a_html_safe_suffix_as_safe_html
    translate(:'translations.array_html').tap do |translated|
      assert_equal %w( foo bar ), translated
      assert translated.all?(&:html_safe?)
    end
  end

  def test_translate_with_default_and_raise_false
    translation = translate(:"translations.missing", default: :"translations.foo", raise: false)
    assert_equal "Foo", translation
  end

  def test_translate_with_default_named_html
    translation = translate(:'translations.missing', default: :'translations.hello_html')
    assert_equal "<a>Hello World</a>", translation
    assert_equal true, translation.html_safe?
  end

  def test_translate_with_default_named_html_and_raise_false
    translation = translate(:"translations.missing", default: :"translations.hello_html", raise: false)
    assert_equal "<a>Hello World</a>", translation
    assert_predicate translation, :html_safe?
  end

  def test_translate_with_missing_default
    translation = translate(:"translations.missing", default: :also_missing)
    expected = '<span class="translation_missing" title="translation missing: en.translations.missing">Missing</span>'
    assert_equal expected, translation
    assert_equal true, translation.html_safe?
  end

  def test_translate_with_missing_default_and_raise_option
    assert_raise(I18n::MissingTranslationData) do
      translate(:'translations.missing', default: :'translations.missing_html', raise: true)
    end
  end

  def test_translate_with_html_key_and_missing_default_and_raise_option
    assert_raise(I18n::MissingTranslationData) do
      translate(:"translations.missing_html", default: :"translations.missing_html", raise: true)
    end
  end

  def test_translate_with_two_defaults_named_html
    translation = translate(:'translations.missing', default: [:'translations.missing_html', :'translations.hello_html'])
    assert_equal "<a>Hello World</a>", translation
    assert_equal true, translation.html_safe?
  end

  def test_translate_with_last_default_named_html
    translation = translate(:'translations.missing', default: [:'translations.missing', :'translations.hello_html'])
    assert_equal "<a>Hello World</a>", translation
    assert_equal true, translation.html_safe?
  end

  def test_translate_with_last_default_not_named_html
    translation = translate(:'translations.missing', default: [:'translations.missing_html', :'translations.foo'])
    assert_equal "Foo", translation
    assert_equal false, translation.html_safe?
  end

  def test_translate_does_not_mark_unsourced_string_default_as_html_safe
    untrusted_string = "<script>alert()</script>"
    translation = translate(:"translations.missing", default: [:"translations.missing_html", untrusted_string])
    assert_equal untrusted_string, translation
    assert_not_predicate translation, :html_safe?
  end

  def test_translate_with_string_default
    translation = translate(:'translations.missing', default: "A Generic String")
    assert_equal "A Generic String", translation
  end

  def test_translate_with_object_default
    translation = translate(:'translations.missing', default: 123)
    assert_equal 123, translation
  end

  def test_translate_with_array_of_string_defaults
    translation = translate(:'translations.missing', default: ["A Generic String", "Second generic string"])
    assert_equal "A Generic String", translation
  end

  def test_translate_with_array_of_defaults_with_nil
    translation = translate(:'translations.missing', default: [:'also_missing', nil, "A Generic String"])
    assert_equal "A Generic String", translation
  end

  def test_translate_with_array_of_array_default
    translation = translate(:'translations.missing', default: [[]])
    assert_equal [], translation
  end

  def test_translate_with_false_default
    translation = translate(:'translations.missing', default: false)
    assert_equal false, translation
  end

  def test_translate_with_nil_default
    translation = translate(:'translations.missing', default: nil)
    assert_nil translation
  end

  def test_translate_bulk_lookup
    translations = translate([:"translations.foo", :"translations.foo"])
    assert_equal ["Foo", "Foo"], translations
  end

  def test_translate_bulk_lookup_with_default
    translations = translate([:"translations.missing", :"translations.missing"], default: :"translations.foo")
    assert_equal ["Foo", "Foo"], translations
  end

  def test_translate_bulk_lookup_html
    translations = translate([:"translations.html", :"translations.hello_html"])
    assert_equal ["<a>Hello World</a>", "<a>Hello World</a>"], translations
    translations.each do |translation|
      assert_predicate translation, :html_safe?
    end
  end

  def test_translate_bulk_lookup_html_with_default
    translations = translate([:"translations.missing", :"translations.missing"], default: :"translations.html")
    assert_equal ["<a>Hello World</a>", "<a>Hello World</a>"], translations
    translations.each do |translation|
      assert_predicate translation, :html_safe?
    end
  end

  def test_translate_does_not_change_options
    options = {}
    if RUBY_VERSION >= "2.7"
      translate(:'translations.missing', **options)
    else
      translate(:'translations.missing', options)
    end
    assert_equal({}, options)
  end
end
