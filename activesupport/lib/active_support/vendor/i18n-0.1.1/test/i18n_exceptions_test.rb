$:.unshift "lib"

require 'rubygems'
require 'test/unit'
require 'mocha'
require 'i18n'
require 'active_support'

class I18nExceptionsTest < Test::Unit::TestCase
  def test_invalid_locale_stores_locale
    force_invalid_locale
  rescue I18n::ArgumentError => e
    assert_nil e.locale
  end

  def test_invalid_locale_message
    force_invalid_locale
  rescue I18n::ArgumentError => e
    assert_equal 'nil is not a valid locale', e.message
  end

  def test_missing_translation_data_stores_locale_key_and_options
    force_missing_translation_data
  rescue I18n::ArgumentError => e
    options = {:scope => :bar}
    assert_equal 'de', e.locale
    assert_equal :foo, e.key
    assert_equal options, e.options
  end

  def test_missing_translation_data_message
    force_missing_translation_data
  rescue I18n::ArgumentError => e
    assert_equal 'translation missing: de, bar, foo', e.message
  end

  def test_invalid_pluralization_data_stores_entry_and_count
    force_invalid_pluralization_data
  rescue I18n::ArgumentError => e
    assert_equal [:bar], e.entry
    assert_equal 1, e.count
  end

  def test_invalid_pluralization_data_message
    force_invalid_pluralization_data
  rescue I18n::ArgumentError => e
    assert_equal 'translation data [:bar] can not be used with :count => 1', e.message
  end

  def test_missing_interpolation_argument_stores_key_and_string
    force_missing_interpolation_argument
  rescue I18n::ArgumentError => e
    assert_equal 'bar', e.key
    assert_equal "{{bar}}", e.string
  end

  def test_missing_interpolation_argument_message
    force_missing_interpolation_argument
  rescue I18n::ArgumentError => e
    assert_equal 'interpolation argument bar missing in "{{bar}}"', e.message
  end

  def test_reserved_interpolation_key_stores_key_and_string
    force_reserved_interpolation_key
  rescue I18n::ArgumentError => e
    assert_equal 'scope', e.key
    assert_equal "{{scope}}", e.string
  end

  def test_reserved_interpolation_key_message
    force_reserved_interpolation_key
  rescue I18n::ArgumentError => e
    assert_equal 'reserved key "scope" used in "{{scope}}"', e.message
  end

  private
    def force_invalid_locale
      I18n.backend.translate nil, :foo
    end

    def force_missing_translation_data
      I18n.backend.store_translations 'de', :bar => nil
      I18n.backend.translate 'de', :foo, :scope => :bar
    end

    def force_invalid_pluralization_data
      I18n.backend.store_translations 'de', :foo => [:bar]
      I18n.backend.translate 'de', :foo, :count => 1
    end

    def force_missing_interpolation_argument
      I18n.backend.store_translations 'de', :foo => "{{bar}}"
      I18n.backend.translate 'de', :foo, :baz => 'baz'
    end

    def force_reserved_interpolation_key
      I18n.backend.store_translations 'de', :foo => "{{scope}}"
      I18n.backend.translate 'de', :foo, :baz => 'baz'
    end
end