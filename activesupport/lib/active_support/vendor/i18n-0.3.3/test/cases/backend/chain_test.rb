# encoding: utf-8

require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')
require 'i18n/backend/chain'

class I18nBackendChainTest < Test::Unit::TestCase
  def setup
    @first  = backend(:en => {
      :foo => 'Foo', :formats => { :short => 'short' }, :plural_1 => { :one => '{{count}}' }
    })
    @second = backend(:en => {
      :bar => 'Bar', :formats => { :long => 'long' }, :plural_2 => { :one => 'one' }
    })
    @chain  = I18n.backend = I18n::Backend::Chain.new(@first, @second)
  end

  define_method "test: looks up translations from the first chained backend" do
    assert_equal 'Foo', @first.send(:translations)[:en][:foo]
    assert_equal 'Foo', I18n.t(:foo)
  end

  define_method "test: looks up translations from the second chained backend" do
    assert_equal 'Bar', @second.send(:translations)[:en][:bar]
    assert_equal 'Bar', I18n.t(:bar)
  end

  define_method "test: defaults only apply to lookups on the last backend in the chain" do
    assert_equal 'Foo', I18n.t(:foo, :default => 'Bah')
    assert_equal 'Bar', I18n.t(:bar, :default => 'Bah')
    assert_equal 'Bah', I18n.t(:bah, :default => 'Bah') # default kicks in only here
  end

  define_method "test: default" do
    assert_equal 'Fuh',  I18n.t(:default => 'Fuh')
    assert_equal 'Zero', I18n.t(:default => { :zero => 'Zero' }, :count => 0)
    assert_equal({ :zero => 'Zero' }, I18n.t(:default => { :zero => 'Zero' }))
    assert_equal 'Foo', I18n.t(:default => :foo)
  end

  define_method "test: namespace lookup collects results from all backends" do
    assert_equal({ :short => 'short', :long => 'long' }, I18n.t(:formats))
  end

  define_method "test: namespace lookup with only the first backend returning a result" do
    assert_equal({ :one => '{{count}}' }, I18n.t(:plural_1))
  end

  define_method "test: pluralization still works" do
    assert_equal '1',   I18n.t(:plural_1, :count => 1)
    assert_equal 'one', I18n.t(:plural_2, :count => 1)
  end

  define_method "test: bulk lookup collects results from all backends" do
    assert_equal ['Foo', 'Bar'], I18n.t([:foo, :bar])
  end

  protected

    def backend(translations)
      backend = I18n::Backend::Simple.new
      translations.each { |locale, translations| backend.store_translations(locale, translations) }
      backend
    end
end
