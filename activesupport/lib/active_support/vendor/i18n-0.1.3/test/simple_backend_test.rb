# encoding: utf-8
$:.unshift "lib"

require 'rubygems'
require 'test/unit'
require 'i18n'
require 'time'
require 'yaml'

module I18nSimpleBackendTestSetup
  def setup_backend
    # backend_reset_translations!
    @backend = I18n::Backend::Simple.new
    @backend.store_translations 'en', :foo => {:bar => 'bar', :baz => 'baz'}
    @locale_dir = File.dirname(__FILE__) + '/locale'
  end
  alias :setup :setup_backend

  # def backend_reset_translations!
  #   I18n::Backend::Simple::ClassMethods.send :class_variable_set, :@@translations, {}
  # end

  def backend_get_translations
    # I18n::Backend::Simple::ClassMethods.send :class_variable_get, :@@translations
    @backend.instance_variable_get :@translations
  end

  def add_datetime_translations
    @backend.store_translations :'de', {
      :date => {
        :formats => {
          :default => "%d.%m.%Y",
          :short => "%d. %b",
          :long => "%d. %B %Y",
        },
        :day_names => %w(Sonntag Montag Dienstag Mittwoch Donnerstag Freitag Samstag),
        :abbr_day_names => %w(So Mo Di Mi Do Fr  Sa),
        :month_names => %w(Januar Februar März April Mai Juni Juli August September Oktober November Dezember).unshift(nil),
        :abbr_month_names => %w(Jan Feb Mar Apr Mai Jun Jul Aug Sep Okt Nov Dez).unshift(nil),
        :order => [:day, :month, :year]
      },
      :time => {
        :formats => {
          :default => "%a, %d. %b %Y %H:%M:%S %z",
          :short => "%d. %b %H:%M",
          :long => "%d. %B %Y %H:%M",
        },
        :am => 'am',
        :pm => 'pm'
      },
      :datetime => {
        :distance_in_words => {
          :half_a_minute => 'half a minute',
          :less_than_x_seconds => {
            :one => 'less than 1 second',
            :other => 'less than {{count}} seconds'
          },
          :x_seconds => {
            :one => '1 second',
            :other => '{{count}} seconds'
          },
          :less_than_x_minutes => {
            :one => 'less than a minute',
            :other => 'less than {{count}} minutes'
          },
          :x_minutes => {
            :one => '1 minute',
            :other => '{{count}} minutes'
          },
          :about_x_hours => {
            :one => 'about 1 hour',
            :other => 'about {{count}} hours'
          },
          :x_days => {
            :one => '1 day',
            :other => '{{count}} days'
          },
          :about_x_months => {
            :one => 'about 1 month',
            :other => 'about {{count}} months'
          },
          :x_months => {
            :one => '1 month',
            :other => '{{count}} months'
          },
          :about_x_years => {
            :one => 'about 1 year',
            :other => 'about {{count}} year'
          },
          :over_x_years => {
            :one => 'over 1 year',
            :other => 'over {{count}} years'
          }
        }
      }
    }
  end
end

class I18nSimpleBackendTranslationsTest < Test::Unit::TestCase
  include I18nSimpleBackendTestSetup

  def test_store_translations_adds_translations # no, really :-)
    @backend.store_translations :'en', :foo => 'bar'
    assert_equal Hash[:'en', {:foo => 'bar'}], backend_get_translations
  end

  def test_store_translations_deep_merges_translations
    @backend.store_translations :'en', :foo => {:bar => 'bar'}
    @backend.store_translations :'en', :foo => {:baz => 'baz'}
    assert_equal Hash[:'en', {:foo => {:bar => 'bar', :baz => 'baz'}}], backend_get_translations
  end

  def test_store_translations_forces_locale_to_sym
    @backend.store_translations 'en', :foo => 'bar'
    assert_equal Hash[:'en', {:foo => 'bar'}], backend_get_translations
  end

  def test_store_translations_converts_keys_to_symbols
    # backend_reset_translations!
    @backend.store_translations 'en', 'foo' => {'bar' => 'bar', 'baz' => 'baz'}
    assert_equal Hash[:'en', {:foo => {:bar => 'bar', :baz => 'baz'}}], backend_get_translations
  end
end

class I18nSimpleBackendAvailableLocalesTest < Test::Unit::TestCase
  def test_available_locales
    @backend = I18n::Backend::Simple.new
    @backend.store_translations 'de', :foo => 'bar'
    @backend.store_translations 'en', :foo => 'foo'

    assert_equal ['de', 'en'], @backend.available_locales.map{|locale| locale.to_s }.sort
  end
end

class I18nSimpleBackendTranslateTest < Test::Unit::TestCase
  include I18nSimpleBackendTestSetup

  def test_translate_calls_lookup_with_locale_given
    @backend.expects(:lookup).with('de', :bar, [:foo]).returns 'bar'
    @backend.translate 'de', :bar, :scope => [:foo]
  end

  def test_given_no_keys_it_returns_the_default
    assert_equal 'default', @backend.translate('en', nil, :default => 'default')
  end

  def test_translate_given_a_symbol_as_a_default_translates_the_symbol
    assert_equal 'bar', @backend.translate('en', nil, :scope => [:foo], :default => :bar)
  end

  def test_translate_given_an_array_as_default_uses_the_first_match
    assert_equal 'bar', @backend.translate('en', :does_not_exist, :scope => [:foo], :default => [:does_not_exist_2, :bar])
  end

  def test_translate_given_an_array_of_inexistent_keys_it_raises_missing_translation_data
    assert_raise I18n::MissingTranslationData do
      @backend.translate('en', :does_not_exist, :scope => [:foo], :default => [:does_not_exist_2, :does_not_exist_3])
    end
  end

  def test_translate_an_array_of_keys_translates_all_of_them
    assert_equal %w(bar baz), @backend.translate('en', [:bar, :baz], :scope => [:foo])
  end

  def test_translate_calls_pluralize
    @backend.expects(:pluralize).with 'en', 'bar', 1
    @backend.translate 'en', :bar, :scope => [:foo], :count => 1
  end

  def test_translate_calls_interpolate
    @backend.expects(:interpolate).with 'en', 'bar', {}
    @backend.translate 'en', :bar, :scope => [:foo]
  end

  def test_translate_calls_interpolate_including_count_as_a_value
    @backend.expects(:interpolate).with 'en', 'bar', {:count => 1}
    @backend.translate 'en', :bar, :scope => [:foo], :count => 1
  end

  def test_translate_given_nil_as_a_locale_raises_an_argument_error
    assert_raise(I18n::InvalidLocale){ @backend.translate nil, :bar }
  end

  def test_translate_with_a_bogus_key_and_no_default_raises_missing_translation_data
    assert_raise(I18n::MissingTranslationData){ @backend.translate 'de', :bogus }
  end
end

class I18nSimpleBackendLookupTest < Test::Unit::TestCase
  include I18nSimpleBackendTestSetup

  # useful because this way we can use the backend with no key for interpolation/pluralization
  def test_lookup_given_nil_as_a_key_returns_nil
    assert_nil @backend.send(:lookup, 'en', nil)
  end

  def test_lookup_given_nested_keys_looks_up_a_nested_hash_value
    assert_equal 'bar', @backend.send(:lookup, 'en', :bar, [:foo])
  end
end

class I18nSimpleBackendPluralizeTest < Test::Unit::TestCase
  include I18nSimpleBackendTestSetup

  def test_pluralize_given_nil_returns_the_given_entry
    entry = {:one => 'bar', :other => 'bars'}
    assert_equal entry, @backend.send(:pluralize, nil, entry, nil)
  end

  def test_pluralize_given_0_returns_zero_string_if_zero_key_given
    assert_equal 'zero', @backend.send(:pluralize, nil, {:zero => 'zero', :one => 'bar', :other => 'bars'}, 0)
  end

  def test_pluralize_given_0_returns_plural_string_if_no_zero_key_given
    assert_equal 'bars', @backend.send(:pluralize, nil, {:one => 'bar', :other => 'bars'}, 0)
  end

  def test_pluralize_given_1_returns_singular_string
    assert_equal 'bar', @backend.send(:pluralize, nil, {:one => 'bar', :other => 'bars'}, 1)
  end

  def test_pluralize_given_2_returns_plural_string
    assert_equal 'bars', @backend.send(:pluralize, nil, {:one => 'bar', :other => 'bars'}, 2)
  end

  def test_pluralize_given_3_returns_plural_string
    assert_equal 'bars', @backend.send(:pluralize, nil, {:one => 'bar', :other => 'bars'}, 3)
  end

  def test_interpolate_given_incomplete_pluralization_data_raises_invalid_pluralization_data
    assert_raise(I18n::InvalidPluralizationData){ @backend.send(:pluralize, nil, {:one => 'bar'}, 2) }
  end

  # def test_interpolate_given_a_string_raises_invalid_pluralization_data
  #   assert_raise(I18n::InvalidPluralizationData){ @backend.send(:pluralize, nil, 'bar', 2) }
  # end
  #
  # def test_interpolate_given_an_array_raises_invalid_pluralization_data
  #   assert_raise(I18n::InvalidPluralizationData){ @backend.send(:pluralize, nil, ['bar'], 2) }
  # end
end

class I18nSimpleBackendInterpolateTest < Test::Unit::TestCase
  include I18nSimpleBackendTestSetup

  def test_interpolate_given_a_value_hash_interpolates_the_values_to_the_string
    assert_equal 'Hi David!', @backend.send(:interpolate, nil, 'Hi {{name}}!', :name => 'David')
  end

  def test_interpolate_given_a_value_hash_interpolates_into_unicode_string
    assert_equal 'Häi David!', @backend.send(:interpolate, nil, 'Häi {{name}}!', :name => 'David')
  end

  def test_interpolate_given_an_unicode_value_hash_interpolates_to_the_string
    assert_equal 'Hi ゆきひろ!', @backend.send(:interpolate, nil, 'Hi {{name}}!', :name => 'ゆきひろ')
  end

  def test_interpolate_given_an_unicode_value_hash_interpolates_into_unicode_string
    assert_equal 'こんにちは、ゆきひろさん!', @backend.send(:interpolate, nil, 'こんにちは、{{name}}さん!', :name => 'ゆきひろ')
  end

  if Kernel.const_defined?(:Encoding)
    def test_interpolate_given_a_non_unicode_multibyte_value_hash_interpolates_into_a_string_with_the_same_encoding
      assert_equal euc_jp('Hi ゆきひろ!'), @backend.send(:interpolate, nil, 'Hi {{name}}!', :name => euc_jp('ゆきひろ'))
    end

    def test_interpolate_given_an_unicode_value_hash_into_a_non_unicode_multibyte_string_raises_encoding_compatibility_error
      assert_raise(Encoding::CompatibilityError) do
        @backend.send(:interpolate, nil, euc_jp('こんにちは、{{name}}さん!'), :name => 'ゆきひろ')
      end
    end

    def test_interpolate_given_a_non_unicode_multibyte_value_hash_into_an_unicode_string_raises_encoding_compatibility_error
      assert_raise(Encoding::CompatibilityError) do
        @backend.send(:interpolate, nil, 'こんにちは、{{name}}さん!', :name => euc_jp('ゆきひろ'))
      end
    end
  end

  def test_interpolate_given_nil_as_a_string_returns_nil
    assert_nil @backend.send(:interpolate, nil, nil, :name => 'David')
  end

  def test_interpolate_given_an_non_string_as_a_string_returns_nil
    assert_equal [], @backend.send(:interpolate, nil, [], :name => 'David')
  end

  def test_interpolate_given_a_values_hash_with_nil_values_interpolates_the_string
    assert_equal 'Hi !', @backend.send(:interpolate, nil, 'Hi {{name}}!', {:name => nil})
  end

  def test_interpolate_given_an_empty_values_hash_raises_missing_interpolation_argument
    assert_raise(I18n::MissingInterpolationArgument) { @backend.send(:interpolate, nil, 'Hi {{name}}!', {}) }
  end

  def test_interpolate_given_a_string_containing_a_reserved_key_raises_reserved_interpolation_key
    assert_raise(I18n::ReservedInterpolationKey) { @backend.send(:interpolate, nil, '{{default}}', {:default => nil}) }
  end
  
  private
  
  def euc_jp(string)
    string.encode!(Encoding::EUC_JP)
  end
end

class I18nSimpleBackendLocalizeDateTest < Test::Unit::TestCase
  include I18nSimpleBackendTestSetup

  def setup
    @backend = I18n::Backend::Simple.new
    add_datetime_translations
    @date = Date.new 2008, 1, 1
  end

  def test_translate_given_the_short_format_it_uses_it
    assert_equal '01. Jan', @backend.localize('de', @date, :short)
  end

  def test_translate_given_the_long_format_it_uses_it
    assert_equal '01. Januar 2008', @backend.localize('de', @date, :long)
  end

  def test_translate_given_the_default_format_it_uses_it
    assert_equal '01.01.2008', @backend.localize('de', @date, :default)
  end

  def test_translate_given_a_day_name_format_it_returns_a_day_name
    assert_equal 'Dienstag', @backend.localize('de', @date, '%A')
  end

  def test_translate_given_an_abbr_day_name_format_it_returns_an_abbrevated_day_name
    assert_equal 'Di', @backend.localize('de', @date, '%a')
  end

  def test_translate_given_a_month_name_format_it_returns_a_month_name
    assert_equal 'Januar', @backend.localize('de', @date, '%B')
  end

  def test_translate_given_an_abbr_month_name_format_it_returns_an_abbrevated_month_name
    assert_equal 'Jan', @backend.localize('de', @date, '%b')
  end

  def test_translate_given_no_format_it_does_not_fail
    assert_nothing_raised{ @backend.localize 'de', @date }
  end

  def test_translate_given_an_unknown_format_it_does_not_fail
    assert_nothing_raised{ @backend.localize 'de', @date, '%x' }
  end

  def test_localize_nil_raises_argument_error
    assert_raise(I18n::ArgumentError) { @backend.localize 'de', nil }
  end

  def test_localize_object_raises_argument_error
    assert_raise(I18n::ArgumentError) { @backend.localize 'de', Object.new }
  end
end

class I18nSimpleBackendLocalizeDateTimeTest < Test::Unit::TestCase
  include I18nSimpleBackendTestSetup

  def setup
    @backend = I18n::Backend::Simple.new
    add_datetime_translations
    @morning = DateTime.new 2008, 1, 1, 6
    @evening = DateTime.new 2008, 1, 1, 18
  end

  def test_translate_given_the_short_format_it_uses_it
    assert_equal '01. Jan 06:00', @backend.localize('de', @morning, :short)
  end

  def test_translate_given_the_long_format_it_uses_it
    assert_equal '01. Januar 2008 06:00', @backend.localize('de', @morning, :long)
  end

  def test_translate_given_the_default_format_it_uses_it
    assert_equal 'Di, 01. Jan 2008 06:00:00 +0000', @backend.localize('de', @morning, :default)
  end

  def test_translate_given_a_day_name_format_it_returns_the_correct_day_name
    assert_equal 'Dienstag', @backend.localize('de', @morning, '%A')
  end

  def test_translate_given_an_abbr_day_name_format_it_returns_the_correct_abbrevated_day_name
    assert_equal 'Di', @backend.localize('de', @morning, '%a')
  end

  def test_translate_given_a_month_name_format_it_returns_the_correct_month_name
    assert_equal 'Januar', @backend.localize('de', @morning, '%B')
  end

  def test_translate_given_an_abbr_month_name_format_it_returns_the_correct_abbrevated_month_name
    assert_equal 'Jan', @backend.localize('de', @morning, '%b')
  end

  def test_translate_given_a_meridian_indicator_format_it_returns_the_correct_meridian_indicator
    assert_equal 'am', @backend.localize('de', @morning, '%p')
    assert_equal 'pm', @backend.localize('de', @evening, '%p')
  end

  def test_translate_given_no_format_it_does_not_fail
    assert_nothing_raised{ @backend.localize 'de', @morning }
  end

  def test_translate_given_an_unknown_format_it_does_not_fail
    assert_nothing_raised{ @backend.localize 'de', @morning, '%x' }
  end
end

class I18nSimpleBackendLocalizeTimeTest < Test::Unit::TestCase
  include I18nSimpleBackendTestSetup

  def setup
    @old_timezone, ENV['TZ'] = ENV['TZ'], 'UTC'
    @backend = I18n::Backend::Simple.new
    add_datetime_translations
    @morning = Time.parse '2008-01-01 6:00 UTC'
    @evening = Time.parse '2008-01-01 18:00 UTC'
  end

  def teardown
    @old_timezone ? ENV['TZ'] = @old_timezone : ENV.delete('TZ')
  end

  def test_translate_given_the_short_format_it_uses_it
    assert_equal '01. Jan 06:00', @backend.localize('de', @morning, :short)
  end

  def test_translate_given_the_long_format_it_uses_it
    assert_equal '01. Januar 2008 06:00', @backend.localize('de', @morning, :long)
  end

  # TODO Seems to break on Windows because ENV['TZ'] is ignored. What's a better way to do this?
  # def test_translate_given_the_default_format_it_uses_it
  #   assert_equal 'Di, 01. Jan 2008 06:00:00 +0000', @backend.localize('de', @morning, :default)
  # end

  def test_translate_given_a_day_name_format_it_returns_the_correct_day_name
    assert_equal 'Dienstag', @backend.localize('de', @morning, '%A')
  end

  def test_translate_given_an_abbr_day_name_format_it_returns_the_correct_abbrevated_day_name
    assert_equal 'Di', @backend.localize('de', @morning, '%a')
  end

  def test_translate_given_a_month_name_format_it_returns_the_correct_month_name
    assert_equal 'Januar', @backend.localize('de', @morning, '%B')
  end

  def test_translate_given_an_abbr_month_name_format_it_returns_the_correct_abbrevated_month_name
    assert_equal 'Jan', @backend.localize('de', @morning, '%b')
  end

  def test_translate_given_a_meridian_indicator_format_it_returns_the_correct_meridian_indicator
    assert_equal 'am', @backend.localize('de', @morning, '%p')
    assert_equal 'pm', @backend.localize('de', @evening, '%p')
  end

  def test_translate_given_no_format_it_does_not_fail
    assert_nothing_raised{ @backend.localize 'de', @morning }
  end

  def test_translate_given_an_unknown_format_it_does_not_fail
    assert_nothing_raised{ @backend.localize 'de', @morning, '%x' }
  end
end

class I18nSimpleBackendHelperMethodsTest < Test::Unit::TestCase
  def setup
    @backend = I18n::Backend::Simple.new
  end

  def test_deep_symbolize_keys_works
    result = @backend.send :deep_symbolize_keys, 'foo' => {'bar' => {'baz' => 'bar'}}
    expected = {:foo => {:bar => {:baz => 'bar'}}}
    assert_equal expected, result
  end
end

class I18nSimpleBackendLoadTranslationsTest < Test::Unit::TestCase
  include I18nSimpleBackendTestSetup

  def test_load_translations_with_unknown_file_type_raises_exception
    assert_raise(I18n::UnknownFileType) { @backend.load_translations "#{@locale_dir}/en.xml" }
  end

  def test_load_translations_with_ruby_file_type_does_not_raise_exception
    assert_nothing_raised { @backend.load_translations "#{@locale_dir}/en.rb" }
  end

  def test_load_rb_loads_data_from_ruby_file
    data = @backend.send :load_rb, "#{@locale_dir}/en.rb"
    assert_equal({:'en-Ruby' => {:foo => {:bar => "baz"}}}, data)
  end

  def test_load_rb_loads_data_from_yaml_file
    data = @backend.send :load_yml, "#{@locale_dir}/en.yml"
    assert_equal({'en-Yaml' => {'foo' => {'bar' => 'baz'}}}, data)
  end

  def test_load_translations_loads_from_different_file_formats
    @backend = I18n::Backend::Simple.new
    @backend.load_translations "#{@locale_dir}/en.rb", "#{@locale_dir}/en.yml"
    expected = {
      :'en-Ruby' => {:foo => {:bar => "baz"}},
      :'en-Yaml' => {:foo => {:bar => "baz"}}
    }
    assert_equal expected, backend_get_translations
  end
end

class I18nSimpleBackendLoadPathTest < Test::Unit::TestCase
  include I18nSimpleBackendTestSetup

  def teardown
    I18n.load_path = []
  end

  def test_nested_load_paths_do_not_break_locale_loading
    @backend = I18n::Backend::Simple.new
    I18n.load_path = [[File.dirname(__FILE__) + '/locale/en.yml']]
    assert_nil backend_get_translations
    assert_nothing_raised { @backend.send :init_translations }
    assert_not_nil backend_get_translations
  end

  def test_adding_arrays_of_filenames_to_load_path_do_not_break_locale_loading
    @backend = I18n::Backend::Simple.new
    I18n.load_path << Dir[File.dirname(__FILE__) + '/locale/*.{rb,yml}']
    assert_nil backend_get_translations
    assert_nothing_raised { @backend.send :init_translations }
    assert_not_nil backend_get_translations
  end
end

class I18nSimpleBackendReloadTranslationsTest < Test::Unit::TestCase
  include I18nSimpleBackendTestSetup
  
  def setup
    @backend = I18n::Backend::Simple.new
    I18n.load_path = [File.dirname(__FILE__) + '/locale/en.yml']
    assert_nil backend_get_translations
    @backend.send :init_translations
  end
  
  def teardown
    I18n.load_path = []
  end
  
  def test_setup
    assert_not_nil backend_get_translations
  end
  
  def test_reload_translations_unloads_translations
    @backend.reload!
    assert_nil backend_get_translations
  end
  
  def test_reload_translations_uninitializes_translations
    @backend.reload!
    assert_equal @backend.initialized?, false
  end
end
