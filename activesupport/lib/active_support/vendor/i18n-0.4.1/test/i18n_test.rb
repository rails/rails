# encoding: utf-8
$:.unshift(File.expand_path(File.dirname(__FILE__))); $:.uniq!
require 'test_helper'

class I18nTest < Test::Unit::TestCase
  def setup
    I18n.backend.store_translations :'en', {
      :currency => {
        :format => {
          :separator => '.',
          :delimiter => ',',
        }
      }
    }
  end

  def test_uses_simple_backend_set_by_default
    assert I18n.backend.is_a?(I18n::Backend::Simple)
  end

  def test_can_set_backend
    assert_nothing_raised { I18n.backend = self }
    assert_equal self, I18n.backend
  ensure
    I18n.backend = I18n::Backend::Simple.new
  end

  def test_uses_en_us_as_default_locale_by_default
    assert_equal :en, I18n.default_locale
  end

  def test_can_set_default_locale
    assert_nothing_raised { I18n.default_locale = 'de' }
    assert_equal :de, I18n.default_locale
  ensure
    I18n.default_locale = :en
  end

  def test_uses_default_locale_as_locale_by_default
    assert_equal I18n.default_locale, I18n.locale
  end

  def test_can_set_locale_to_thread_current
    assert_nothing_raised { I18n.locale = 'de' }
    assert_equal :de, I18n.locale
    assert_equal :de, Thread.current[:i18n_config].locale
    I18n.locale = :en
  end

  def test_can_set_i18n_config
    I18n.config = self
    assert_equal self, I18n.config
    assert_equal self, Thread.current[:i18n_config]
  ensure
    I18n.config = ::I18n::Config.new
  end

  def test_locale_is_not_shared_between_configurations
    a = I18n::Config.new
    b = I18n::Config.new
    a.locale = :fr
    b.locale = :es
    assert_equal :fr, a.locale
    assert_equal :es, b.locale
    assert_equal :en, I18n.locale
  end

  def test_other_options_are_shared_between_configurations
    a = I18n::Config.new
    b = I18n::Config.new
    a.default_locale = :fr
    b.default_locale = :es
    assert_equal :es, a.default_locale
    assert_equal :es, b.default_locale
    assert_equal :es, I18n.default_locale
  ensure
    I18n.default_locale = :en
  end

  def test_defaults_to_dot_as_separator
    assert_equal '.', I18n.default_separator
  end

  def test_can_set_default_separator
    assert_nothing_raised { I18n.default_separator = "\001" }
  ensure
    I18n.default_separator = '.' # revert it
  end

  def test_normalize_keys
    assert_equal [:en, :foo, :bar], I18n.normalize_keys(:en, :bar, :foo)
    assert_equal [:en, :foo, :bar, :baz, :buz], I18n.normalize_keys(:en, :'baz.buz', :'foo.bar')
    assert_equal [:en, :foo, :bar, :baz, :buz], I18n.normalize_keys(:en, 'baz.buz', 'foo.bar')
    assert_equal [:en, :foo, :bar, :baz, :buz], I18n.normalize_keys(:en, %w(baz buz), %w(foo bar))
    assert_equal [:en, :foo, :bar, :baz, :buz], I18n.normalize_keys(:en, [:baz, :buz], [:foo, :bar])
  end

  def test_normalize_keys_should_not_attempt_to_sym_on_empty_string
    assert_equal [:en, :foo, :bar, :baz, :buz], I18n.normalize_keys(:en, :'baz.buz', :'foo..bar')
    assert_equal [:en, :foo, :bar, :baz, :buz], I18n.normalize_keys(:en, :'baz.buz', :'foo......bar')
  end

  def test_uses_passed_separator_to_normalize_keys
    assert_equal [:en, :foo, :bar, :baz, :buz], I18n.normalize_keys(:en, :'baz|buz', :'foo|bar', '|')
  end

  def test_can_set_exception_handler
    assert_nothing_raised { I18n.exception_handler = :custom_exception_handler }
  ensure
    I18n.exception_handler = :default_exception_handler
  end

  with_mocha do
    def test_uses_custom_exception_handler
      I18n.exception_handler = :custom_exception_handler
      I18n.expects(:custom_exception_handler)
      I18n.translate :bogus
    ensure
      I18n.exception_handler = :default_exception_handler # revert it
    end

    def test_delegates_translate_to_backend
      I18n.backend.expects(:translate).with('de', :foo, {})
      I18n.translate :foo, :locale => 'de'
    end

    def test_delegates_localize_to_backend
      I18n.backend.expects(:localize).with('de', :whatever, :default, {})
      I18n.localize :whatever, :locale => 'de'
    end

    def test_translate_given_no_locale_uses_i18n_locale
      I18n.backend.expects(:translate).with(:en, :foo, {})
      I18n.translate :foo
    end
  end

  def test_translate_on_nested_symbol_keys_works
    assert_equal ".", I18n.t(:'currency.format.separator')
  end

  def test_translate_with_nested_string_keys_works
    assert_equal ".", I18n.t('currency.format.separator')
  end

  def test_translate_with_array_as_scope_works
    assert_equal ".", I18n.t(:separator, :scope => %w(currency format))
  end

  def test_translate_with_array_containing_dot_separated_strings_as_scope_works
    assert_equal ".", I18n.t(:separator, :scope => ['currency.format'])
  end

  def test_translate_with_key_array_and_dot_separated_scope_works
    assert_equal [".", ","], I18n.t(%w(separator delimiter), :scope => 'currency.format')
  end

  def test_translate_with_dot_separated_key_array_and_scope_works
    assert_equal [".", ","], I18n.t(%w(format.separator format.delimiter), :scope => 'currency')
  end

  # with_mocha do
  #   def test_translate_with_options_using_scope_works
  #     I18n.backend.expects(:translate).with('de', :precision, :scope => :"currency.format")
  #     I18n.with_options :locale => 'de', :scope => :'currency.format' do |locale|
  #       locale.t :precision
  #     end
  #   end
  # end

  # def test_translate_given_no_args_raises_missing_translation_data
  #   assert_equal "translation missing: en, no key", I18n.t
  # end

  def test_translate_given_a_bogus_key_raises_missing_translation_data
    assert_equal "translation missing: en, bogus", I18n.t(:bogus)
  end

  def test_localize_nil_raises_argument_error
    assert_raise(I18n::ArgumentError) { I18n.l nil }
  end

  def test_localize_object_raises_argument_error
    assert_raise(I18n::ArgumentError) { I18n.l Object.new }
  end

  def test_proc_exception_handler
    I18n.exception_handler = Proc.new { |exception, locale, key, options|
      "No exception here! [Proc handler]"
    }
    assert_equal "No exception here! [Proc handler]", I18n.translate(:test_proc_handler)
  ensure
    I18n.exception_handler = :default_exception_handler
  end

  def test_class_exception_handler
    I18n.exception_handler = Class.new do
      def call(exception, locale, key, options)
        "No exception here! [Class handler]"
      end
    end.new
    assert_equal "No exception here! [Class handler]", I18n.translate(:test_class_handler)
  ensure
    I18n.exception_handler = :default_exception_handler
  end

  test "I18n.with_locale" do
    store_translations(:en, :foo => 'Foo in :en')
    store_translations(:de, :foo => 'Foo in :de')
    store_translations(:pl, :foo => 'Foo in :pl')

    I18n.with_locale do
      assert_equal I18n.default_locale, I18n.locale
      assert_equal 'Foo in :en', I18n.t(:foo)
    end

    I18n.with_locale(:de) do
      assert_equal :de, I18n.locale
      assert_equal 'Foo in :de', I18n.t(:foo)
    end

    I18n.with_locale(:pl) do
      assert_equal :pl, I18n.locale
      assert_equal 'Foo in :pl', I18n.t(:foo)
    end
    
    I18n.with_locale(:en) do
      assert_equal :en, I18n.locale
      assert_equal 'Foo in :en', I18n.t(:foo)
    end

    assert_equal I18n.default_locale, I18n.locale
  end

  test "whether I18n.with_locale reset the locale in case of errors" do
    assert_raise(I18n::ArgumentError) do
      I18n.with_locale(:pl) do
        raise I18n::ArgumentError
      end
    end
    assert_equal I18n.default_locale, I18n.locale
  end

end
