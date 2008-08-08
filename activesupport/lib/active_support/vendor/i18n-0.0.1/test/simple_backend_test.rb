$:.unshift "lib"

require 'rubygems'
require 'test/unit'
require 'mocha'
require 'i18n'

module I18nSimpleBackendTestSetup
  def setup_backend
    @backend = I18n::Backend::Simple
    @backend.send :class_variable_set, :@@translations, {}
    @backend.store_translations 'en-US', :foo => {:bar => 'bar', :baz => 'baz'}
  end
  alias :setup :setup_backend
  
  def add_datetime_translations
    @backend.store_translations :'de-DE', {
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
          :half_a_minute       => 'half a minute',
          :less_than_x_seconds => ['less than 1 second', 'less than {{count}} seconds'],
          :x_seconds           => ['1 second', '{{count}} seconds'],
          :less_than_x_minutes => ['less than a minute', 'less than {{count}} minutes'],
          :x_minutes           => ['1 minute', '{{count}} minutes'],
          :about_x_hours       => ['about 1 hour', 'about {{count}} hours'],
          :x_days              => ['1 day', '{{count}} days'],
          :about_x_months      => ['about 1 month', 'about {{count}} months'],
          :x_months            => ['1 month', '{{count}} months'],
          :about_x_years       => ['about 1 year', 'about {{count}} year'],
          :over_x_years        => ['over 1 year', 'over {{count}} years']
        }
      }  
    }
  end
end

class I18nSimpleBackendTranslationsTest < Test::Unit::TestCase
  include I18nSimpleBackendTestSetup
  
  def test_store_translations_adds_translations # no, really :-)
    @backend.store_translations :'en-US', :foo => 'bar'
    assert_equal Hash[:'en-US', {:foo => 'bar'}], @backend.send(:class_variable_get, :@@translations)
  end
  
  def test_store_translations_deep_merges_translations
    @backend.store_translations :'en-US', :foo => {:bar => 'bar'}
    @backend.store_translations :'en-US', :foo => {:baz => 'baz'}
    assert_equal Hash[:'en-US', {:foo => {:bar => 'bar', :baz => 'baz'}}], @backend.send(:class_variable_get, :@@translations)
  end
  
  def test_store_translations_forces_locale_to_sym
    @backend.store_translations 'en-US', :foo => 'bar'
    assert_equal Hash[:'en-US', {:foo => 'bar'}], @backend.send(:class_variable_get, :@@translations)
  end
  
  def test_store_translations_covert_key_symbols
    @backend.send :class_variable_set, :@@translations, {}  # reset translations
    @backend.store_translations :'en-US', 'foo' => {'bar' => 'baz'}
    assert_equal Hash[:'en-US', {:foo => {:bar => 'baz'}}], 
      @backend.send(:class_variable_get, :@@translations)      
  end
end
  
class I18nSimpleBackendTranslateTest < Test::Unit::TestCase
  include I18nSimpleBackendTestSetup

  def test_translate_calls_lookup_with_locale_given
    @backend.expects(:lookup).with('de-DE', :bar, [:foo]).returns 'bar'
    @backend.translate 'de-DE', :bar, :scope => [:foo]
  end
  
  def test_translate_given_a_symbol_as_a_default_translates_the_symbol
    assert_equal 'bar', @backend.translate('en-US', nil, :scope => [:foo], :default => :bar)
  end
  
  def test_translate_given_an_array_as_default_uses_the_first_match
    assert_equal 'bar', @backend.translate('en-US', :does_not_exist, :scope => [:foo], :default => [:does_not_exist_2, :bar])
  end
  
  def test_translate_an_array_of_keys_translates_all_of_them
    assert_equal %w(bar baz), @backend.translate('en-US', [:bar, :baz], :scope => [:foo])
  end
  
  def test_translate_calls_pluralize
    @backend.expects(:pluralize).with 'bar', 1
    @backend.translate 'en-US', :bar, :scope => [:foo], :count => 1
  end
  
  def test_translate_calls_interpolate
    @backend.expects(:interpolate).with 'bar', {}
    @backend.translate 'en-US', :bar, :scope => [:foo]
  end
  
  def test_translate_calls_interpolate_including_count_as_a_value
    @backend.expects(:interpolate).with 'bar', {:count => 1}
    @backend.translate 'en-US', :bar, :scope => [:foo], :count => 1
  end
  
  def test_given_no_keys_it_returns_the_default
    assert_equal 'default', @backend.translate('en-US', nil, :default => 'default')    
  end
  
  def test_translate_given_nil_as_a_locale_raises_an_argument_error
    assert_raises(I18n::InvalidLocale){ @backend.translate nil, :bar }
  end
  
  def test_translate_with_a_bogus_key_and_no_default_raises_missing_translation_data
    assert_raises(I18n::MissingTranslationData){ @backend.translate 'de-DE', :bogus }
  end
end
  
class I18nSimpleBackendLookupTest < Test::Unit::TestCase
  include I18nSimpleBackendTestSetup
  
  # useful because this way we can use the backend with no key for interpolation/pluralization
  def test_lookup_given_nil_as_a_key_returns_nil 
    assert_nil @backend.send(:lookup, 'en-US', nil)
  end
  
  def test_lookup_given_nested_keys_looks_up_a_nested_hash_value
    assert_equal 'bar', @backend.send(:lookup, 'en-US', :bar, [:foo])
  end
end
  
class I18nSimpleBackendPluralizeTest < Test::Unit::TestCase
  include I18nSimpleBackendTestSetup
  
  def test_pluralize_given_nil_returns_the_given_entry
    assert_equal ['bar', 'bars'], @backend.send(:pluralize, ['bar', 'bars'], nil)
  end
  
  def test_pluralize_given_0_returns_plural_string
    assert_equal 'bars', @backend.send(:pluralize, ['bar', 'bars'], 0)
  end
  
  def test_pluralize_given_1_returns_singular_string
    assert_equal 'bar', @backend.send(:pluralize, ['bar', 'bars'], 1)
  end
  
  def test_pluralize_given_2_returns_plural_string
    assert_equal 'bars', @backend.send(:pluralize, ['bar', 'bars'], 2)
  end
  
  def test_pluralize_given_3_returns_plural_string
    assert_equal 'bars', @backend.send(:pluralize, ['bar', 'bars'], 3)
  end
  
  def test_interpolate_given_invalid_pluralization_data_raises_invalid_pluralization_data
    assert_raises(I18n::InvalidPluralizationData){ @backend.send(:pluralize, ['bar'], 2) }
  end
end
  
class I18nSimpleBackendInterpolateTest < Test::Unit::TestCase
  include I18nSimpleBackendTestSetup
  
  def test_interpolate_given_a_value_hash_interpolates_the_values_to_the_string
    assert_equal 'Hi David!', @backend.send(:interpolate, 'Hi {{name}}!', :name => 'David')
  end
  
  def test_interpolate_given_nil_as_a_string_returns_nil
    assert_nil @backend.send(:interpolate, nil, :name => 'David')
  end
  
  def test_interpolate_given_an_non_string_as_a_string_returns_nil
    assert_equal [], @backend.send(:interpolate, [], :name => 'David')
  end
  
  def test_interpolate_given_a_values_hash_with_nil_values_interpolates_the_string
    assert_equal 'Hi !', @backend.send(:interpolate, 'Hi {{name}}!', {:name => nil})
  end
  
  def test_interpolate_given_an_empty_values_hash_raises_missing_interpolation_argument
    assert_raises(I18n::MissingInterpolationArgument) { @backend.send(:interpolate, 'Hi {{name}}!', {}) }
  end
  
  def test_interpolate_given_a_string_containing_a_reserved_key_raises_reserved_interpolation_key
    assert_raises(I18n::ReservedInterpolationKey) { @backend.send(:interpolate, '{{default}}', {:default => nil}) }
  end
end

class I18nSimpleBackendLocalizeDateTest < Test::Unit::TestCase
  include I18nSimpleBackendTestSetup
  
  def setup
    @backend = I18n::Backend::Simple
    add_datetime_translations
    @date = Date.new 2008, 1, 1
  end
  
  def test_translate_given_the_short_format_it_uses_it
    assert_equal '01. Jan', @backend.localize('de-DE', @date, :short)
  end
  
  def test_translate_given_the_long_format_it_uses_it
    assert_equal '01. Januar 2008', @backend.localize('de-DE', @date, :long)
  end
  
  def test_translate_given_the_default_format_it_uses_it
    assert_equal '01.01.2008', @backend.localize('de-DE', @date, :default)
  end
  
  def test_translate_given_a_day_name_format_it_returns_a_day_name
    assert_equal 'Dienstag', @backend.localize('de-DE', @date, '%A')
  end
  
  def test_translate_given_an_abbr_day_name_format_it_returns_an_abbrevated_day_name
    assert_equal 'Di', @backend.localize('de-DE', @date, '%a')
  end
  
  def test_translate_given_a_month_name_format_it_returns_a_month_name
    assert_equal 'Januar', @backend.localize('de-DE', @date, '%B')
  end
  
  def test_translate_given_an_abbr_month_name_format_it_returns_an_abbrevated_month_name
    assert_equal 'Jan', @backend.localize('de-DE', @date, '%b')
  end
  
  def test_translate_given_no_format_it_does_not_fail
    assert_nothing_raised{ @backend.localize 'de-DE', @date }
  end
  
  def test_translate_given_an_unknown_format_it_does_not_fail
    assert_nothing_raised{ @backend.localize 'de-DE', @date, '%x' }
  end  
  
  def test_localize_nil_raises_argument_error
    assert_raises(I18n::ArgumentError) { @backend.localize 'de-DE', nil }
  end
  
  def test_localize_object_raises_argument_error
    assert_raises(I18n::ArgumentError) { @backend.localize 'de-DE', Object.new }
  end
end

class I18nSimpleBackendLocalizeDateTimeTest < Test::Unit::TestCase
  include I18nSimpleBackendTestSetup
  
  def setup
    @backend = I18n::Backend::Simple
    add_datetime_translations
    @morning = DateTime.new 2008, 1, 1, 6
    @evening = DateTime.new 2008, 1, 1, 18
  end
  
  def test_translate_given_the_short_format_it_uses_it
    assert_equal '01. Jan 06:00', @backend.localize('de-DE', @morning, :short)
  end
  
  def test_translate_given_the_long_format_it_uses_it
    assert_equal '01. Januar 2008 06:00', @backend.localize('de-DE', @morning, :long)
  end
  
  def test_translate_given_the_default_format_it_uses_it
    assert_equal 'Di, 01. Jan 2008 06:00:00 +0000', @backend.localize('de-DE', @morning, :default)
  end
  
  def test_translate_given_a_day_name_format_it_returns_the_correct_day_name
    assert_equal 'Dienstag', @backend.localize('de-DE', @morning, '%A')
  end
  
  def test_translate_given_an_abbr_day_name_format_it_returns_the_correct_abbrevated_day_name
    assert_equal 'Di', @backend.localize('de-DE', @morning, '%a')
  end
  
  def test_translate_given_a_month_name_format_it_returns_the_correct_month_name
    assert_equal 'Januar', @backend.localize('de-DE', @morning, '%B')
  end
  
  def test_translate_given_an_abbr_month_name_format_it_returns_the_correct_abbrevated_month_name
    assert_equal 'Jan', @backend.localize('de-DE', @morning, '%b')
  end
  
  def test_translate_given_a_meridian_indicator_format_it_returns_the_correct_meridian_indicator
    assert_equal 'am', @backend.localize('de-DE', @morning, '%p')
    assert_equal 'pm', @backend.localize('de-DE', @evening, '%p')
  end
  
  def test_translate_given_no_format_it_does_not_fail
    assert_nothing_raised{ @backend.localize 'de-DE', @morning }
  end
  
  def test_translate_given_an_unknown_format_it_does_not_fail
    assert_nothing_raised{ @backend.localize 'de-DE', @morning, '%x' }
  end 
end

class I18nSimpleBackendLocalizeTimeTest < Test::Unit::TestCase
  include I18nSimpleBackendTestSetup
  
  def setup
    @old_timezone, ENV['TZ'] = ENV['TZ'], 'UTC'
    @backend = I18n::Backend::Simple
    add_datetime_translations
    @morning = Time.parse '2008-01-01 6:00 UTC'
    @evening = Time.parse '2008-01-01 18:00 UTC'
  end
  
  def teardown
    ENV['TZ'] = @old_timezone
  end
  
  def test_translate_given_the_short_format_it_uses_it
    assert_equal '01. Jan 06:00', @backend.localize('de-DE', @morning, :short)
  end
  
  def test_translate_given_the_long_format_it_uses_it
    assert_equal '01. Januar 2008 06:00', @backend.localize('de-DE', @morning, :long)
  end
  
  # TODO Seems to break on Windows because ENV['TZ'] is ignored. What's a better way to do this?
  # def test_translate_given_the_default_format_it_uses_it
  #   assert_equal 'Di, 01. Jan 2008 06:00:00 +0000', @backend.localize('de-DE', @morning, :default)
  # end
  
  def test_translate_given_a_day_name_format_it_returns_the_correct_day_name
    assert_equal 'Dienstag', @backend.localize('de-DE', @morning, '%A')
  end
  
  def test_translate_given_an_abbr_day_name_format_it_returns_the_correct_abbrevated_day_name
    assert_equal 'Di', @backend.localize('de-DE', @morning, '%a')
  end
  
  def test_translate_given_a_month_name_format_it_returns_the_correct_month_name
    assert_equal 'Januar', @backend.localize('de-DE', @morning, '%B')
  end
  
  def test_translate_given_an_abbr_month_name_format_it_returns_the_correct_abbrevated_month_name
    assert_equal 'Jan', @backend.localize('de-DE', @morning, '%b')
  end
  
  def test_translate_given_a_meridian_indicator_format_it_returns_the_correct_meridian_indicator
    assert_equal 'am', @backend.localize('de-DE', @morning, '%p')
    assert_equal 'pm', @backend.localize('de-DE', @evening, '%p')
  end
  
  def test_translate_given_no_format_it_does_not_fail
    assert_nothing_raised{ @backend.localize 'de-DE', @morning }
  end
  
  def test_translate_given_an_unknown_format_it_does_not_fail
    assert_nothing_raised{ @backend.localize 'de-DE', @morning, '%x' }
  end
end

class I18nSimpleBackendHelperMethodsTest < Test::Unit::TestCase
  def setup
    @backend = I18n::Backend::Simple
  end
  
  def test_deep_symbolize_keys_works
    result = @backend.send :deep_symbolize_keys, 'foo' => {'bar' => {'baz' => 'bar'}}
    expected = {:foo => {:bar => {:baz => 'bar'}}}
    assert_equal expected, result
  end
end
