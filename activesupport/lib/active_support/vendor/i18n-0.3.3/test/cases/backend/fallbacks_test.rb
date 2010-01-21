# encoding: utf-8

require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

class I18nBackendFallbacksTest < Test::Unit::TestCase
  class Backend
    include I18n::Backend::Base
    include I18n::Backend::Fallbacks
  end

  def setup
    I18n.backend = Backend.new
    store_translations(:en, :foo => 'Foo in :en', :bar => 'Bar in :en', :buz => 'Buz in :en')
    store_translations(:de, :bar => 'Bar in :de', :baz => 'Baz in :de')
    store_translations(:'de-DE', :baz => 'Baz in :de-DE')
  end

  define_method "test: still returns an existing translation as usual" do
    assert_equal 'Foo in :en', I18n.t(:foo, :locale => :en)
    assert_equal 'Bar in :de', I18n.t(:bar, :locale => :de)
    assert_equal 'Baz in :de-DE', I18n.t(:baz, :locale => :'de-DE')
  end

  define_method "test: returns the :en translation for a missing :de translation" do
    assert_equal 'Foo in :en', I18n.t(:foo, :locale => :de)
  end

  define_method "test: returns the :de translation for a missing :'de-DE' translation" do
    assert_equal 'Bar in :de', I18n.t(:bar, :locale => :'de-DE')
  end

  define_method "test: returns the :en translation for translation missing in both :de and :'de-De'" do
    assert_equal 'Buz in :en', I18n.t(:buz, :locale => :'de-DE')
  end

  define_method "test: raises I18n::MissingTranslationData exception when no translation was found" do
    assert_raises(I18n::MissingTranslationData) { I18n.t(:faa, :locale => :en, :raise => true) }
    assert_raises(I18n::MissingTranslationData) { I18n.t(:faa, :locale => :de, :raise => true) }
  end
end

class I18nBackendFallbacksWithChainTest < Test::Unit::TestCase
  class Backend
    include I18n::Backend::Base
    include I18n::Backend::Fallbacks
  end

  def setup
    backend = Backend.new
    backend.store_translations(:de, :foo => 'FOO')
    I18n.backend = I18n::Backend::Chain.new(I18n::Backend::Simple.new, backend)
  end

  define_method "test: falls back from de-DE to de when there is no translation for de-DE available" do
    assert_equal 'FOO', I18n.t(:foo, :locale => :'de-DE')
  end
end
