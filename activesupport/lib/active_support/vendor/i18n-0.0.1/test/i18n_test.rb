$:.unshift "lib"

require 'rubygems'
require 'test/unit'
require 'mocha'
require 'i18n'
require 'active_support'

class I18nTest < Test::Unit::TestCase
  def setup
    I18n.store_translations :'en-US', {
      :currency => {
        :format => {
          :separator => '.',
          :delimiter => ',',
        }
      }
    }
  end
  
  def test_uses_simple_backend_set_by_default
    assert_equal I18n::Backend::Simple, I18n.backend
  end
  
  def test_can_set_backend
    assert_nothing_raised{ I18n.backend = self }
    assert_equal self, I18n.backend
    I18n.backend = I18n::Backend::Simple
  end
  
  def test_uses_en_us_as_default_locale_by_default
    assert_equal 'en-US', I18n.default_locale
  end
  
  def test_can_set_default_locale
    assert_nothing_raised{ I18n.default_locale = 'de-DE' }
    assert_equal 'de-DE', I18n.default_locale
    I18n.default_locale = 'en-US'
  end
  
  def test_uses_default_locale_as_locale_by_default
    assert_equal I18n.default_locale, I18n.locale
  end
  
  def test_can_set_locale_to_thread_current
    assert_nothing_raised{ I18n.locale = 'de-DE' }
    assert_equal 'de-DE', I18n.locale
    assert_equal 'de-DE', Thread.current[:locale]
    I18n.locale = 'en-US'
  end
  
  def test_can_set_exception_handler
    assert_nothing_raised{ I18n.exception_handler = :custom_exception_handler }
    I18n.exception_handler = :default_exception_handler # revert it
  end
  
  def test_uses_custom_exception_handler
    I18n.exception_handler = :custom_exception_handler
    I18n.expects(:custom_exception_handler)
    I18n.translate :bogus
    I18n.exception_handler = :default_exception_handler # revert it
  end
  
  def test_delegates_translate_to_backend
    I18n.backend.expects(:translate).with 'de-DE', :foo, {}
    I18n.translate :foo, :locale => 'de-DE'
  end
  
  def test_delegates_localize_to_backend
    I18n.backend.expects(:localize).with 'de-DE', :whatever, :default
    I18n.localize :whatever, :locale => 'de-DE'
  end
  
  def test_delegates_store_translations_to_backend
    I18n.backend.expects(:store_translations).with 'de-DE', {:foo => :bar}
    I18n.store_translations 'de-DE', {:foo => :bar}
  end
  
  def test_delegates_populate_to_backend
    I18n.backend.expects(:populate) # can't specify a block here as an expected argument
    I18n.populate{ }
  end
  
  def test_populate_yields_the_block
    tmp = nil
    I18n.populate do tmp = 'yielded' end
    assert_equal 'yielded', tmp
  end
  
  def test_translate_given_no_locale_uses_i18n_locale
    I18n.backend.expects(:translate).with 'en-US', :foo, {}
    I18n.translate :foo
  end  
  
  def test_translate_on_nested_symbol_keys_works
    assert_equal ".", I18n.t(:'currency.format.separator')
  end
  
  def test_translate_with_nested_string_keys_works
    assert_equal ".", I18n.t('currency.format.separator')
  end
  
  def test_translate_with_array_as_scope_works
    assert_equal ".", I18n.t(:separator, :scope => ['currency.format'])
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
  
  def test_translate_with_options_using_scope_works
    I18n.backend.expects(:translate).with('de-DE', :precision, :scope => :"currency.format")
    I18n.with_options :locale => 'de-DE', :scope => :'currency.format' do |locale|
      locale.t :precision
    end
  end
  
  # def test_translate_given_no_args_raises_missing_translation_data
  #   assert_equal "translation missing: en-US, no key", I18n.t
  # end
  
  def test_translate_given_a_bogus_key_raises_missing_translation_data
    assert_equal "translation missing: en-US, bogus", I18n.t(:bogus)
  end
  
  def test_localize_nil_raises_argument_error
    assert_raises(I18n::ArgumentError) { I18n.l nil }
  end
  
  def test_localize_object_raises_argument_error
    assert_raises(I18n::ArgumentError) { I18n.l Object.new }
  end
end
