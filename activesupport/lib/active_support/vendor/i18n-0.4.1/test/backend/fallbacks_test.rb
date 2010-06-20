# encoding: utf-8
$:.unshift(File.expand_path(File.dirname(__FILE__) + '/../')); $:.uniq!
require 'test_helper'

class I18nBackendFallbacksTranslateTest < Test::Unit::TestCase
  class Backend < I18n::Backend::Simple
    include I18n::Backend::Fallbacks
  end

  def setup
    I18n.backend = Backend.new
    store_translations(:en, :foo => 'Foo in :en', :bar => 'Bar in :en', :buz => 'Buz in :en')
    store_translations(:de, :bar => 'Bar in :de', :baz => 'Baz in :de')
    store_translations(:'de-DE', :baz => 'Baz in :de-DE')
  end

  test "still returns an existing translation as usual" do
    assert_equal 'Foo in :en', I18n.t(:foo, :locale => :en)
    assert_equal 'Bar in :de', I18n.t(:bar, :locale => :de)
    assert_equal 'Baz in :de-DE', I18n.t(:baz, :locale => :'de-DE')
  end

  test "returns the :en translation for a missing :de translation" do
    assert_equal 'Foo in :en', I18n.t(:foo, :locale => :de)
  end

  test "returns the :de translation for a missing :'de-DE' translation" do
    assert_equal 'Bar in :de', I18n.t(:bar, :locale => :'de-DE')
  end

  test "returns the :en translation for translation missing in both :de and :'de-De'" do
    assert_equal 'Buz in :en', I18n.t(:buz, :locale => :'de-DE')
  end

  test "returns the :de translation for a missing :'de-DE' when :default is a String" do
    assert_equal 'Bar in :de', I18n.t(:bar, :locale => :'de-DE', :default => "Default Bar")
    assert_equal "Default Bar", I18n.t(:missing_bar, :locale => :'de-DE', :default => "Default Bar")
  end

  test "returns the :'de-DE' default :baz translation for a missing :'de-DE' when defaults contains Symbol" do
    assert_equal 'Baz in :de-DE', I18n.t(:missing_foo, :locale => :'de-DE', :default => [:baz, "Default Bar"])
  end

  test "returns the defaults translation for a missing :'de-DE' when defaults a contains String before Symbol" do
    assert_equal "Default Bar", I18n.t(:missing_foo, :locale => :'de-DE', :default => [:missing_bar, "Default Bar", :baz])
  end

  test "returns the default translation for a missing :'de-DE' and existing :de when default is a Hash" do
    assert_equal 'Default 6 Bars', I18n.t(:missing_foo, :locale => :'de-DE', :default => [:missing_bar, {:other => "Default %{count} Bars"}, "Default Bar"], :count => 6)
  end

  test "raises I18n::MissingTranslationData exception when no translation was found" do
    assert_raise(I18n::MissingTranslationData) { I18n.t(:faa, :locale => :en, :raise => true) }
    assert_raise(I18n::MissingTranslationData) { I18n.t(:faa, :locale => :de, :raise => true) }
  end
end

class I18nBackendFallbacksLocalizeTest < Test::Unit::TestCase
  class Backend < I18n::Backend::Simple
    include I18n::Backend::Fallbacks
  end

  def setup
    I18n.backend = Backend.new
    store_translations(:en, :date => { :formats => { :en => 'en' }, :day_names => %w(Sunday) })
    store_translations(:de, :date => { :formats => { :de => 'de' } })
  end

  test "still uses an existing format as usual" do
    assert_equal 'en', I18n.l(Date.today, :format => :en, :locale => :en)
  end

  test "looks up and uses a fallback locale's format for a key missing in the given locale (1)" do
    assert_equal 'en', I18n.l(Date.today, :format => :en, :locale => :de)
  end

  test "looks up and uses a fallback locale's format for a key missing in the given locale (2)" do
    assert_equal 'de', I18n.l(Date.today, :format => :de, :locale => :'de-DE')
  end

  test "still uses an existing day name translation as usual" do
    assert_equal 'Sunday', I18n.l(Date.new(2010, 1, 3), :format => '%A', :locale => :en)
  end

  test "uses a fallback locale's translation for a key missing in the given locale" do
    assert_equal 'Sunday', I18n.l(Date.new(2010, 1, 3), :format => '%A', :locale => :de)
  end
end

class I18nBackendFallbacksWithChainTest < Test::Unit::TestCase
  class Backend < I18n::Backend::Simple
    include I18n::Backend::Fallbacks
  end

  def setup
    backend = Backend.new
    backend.store_translations(:de, :foo => 'FOO')
    I18n.backend = I18n::Backend::Chain.new(I18n::Backend::Simple.new, backend)
  end

  test "falls back from de-DE to de when there is no translation for de-DE available" do
    assert_equal 'FOO', I18n.t(:foo, :locale => :'de-DE')
  end
end
