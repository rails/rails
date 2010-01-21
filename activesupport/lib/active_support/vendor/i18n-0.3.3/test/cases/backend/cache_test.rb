# encoding: utf-8

require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')
require 'i18n/backend/cache'

begin
  require 'active_support'
rescue LoadError
  $stderr.puts "Skipping cache tests using ActiveSupport"
else

class I18nBackendCacheTest < Test::Unit::TestCase
  class Backend
    include I18n::Backend::Base
    include I18n::Backend::Cache
  end

  def setup
    I18n.backend = Backend.new
    super
    I18n.cache_store = ActiveSupport::Cache.lookup_store(:memory_store)
  end

  def teardown
    I18n.cache_store = nil
  end

  def test_uses_cache
    assert I18n.cache_store.is_a?(ActiveSupport::Cache::MemoryStore)
  end

  with_mocha do
    define_method "test translate hits the backend and caches the response" do
      I18n.backend.expects(:lookup).returns('Foo')
      assert_equal 'Foo', I18n.t(:foo)

      I18n.backend.expects(:lookup).never
      assert_equal 'Foo', I18n.t(:foo)

      I18n.backend.expects(:lookup).returns('Bar')
      assert_equal 'Bar', I18n.t(:bar)
    end

    define_method "test still raises MissingTranslationData but also caches it" do
      I18n.backend.expects(:lookup).returns(nil)
      assert_raises(I18n::MissingTranslationData) { I18n.t(:missing, :raise => true) }

      I18n.backend.expects(:lookup).never
      assert_raises(I18n::MissingTranslationData) { I18n.t(:missing, :raise => true) }
    end
  end

  define_method "test uses 'i18n' as a cache key namespace by default" do
    assert_equal 0, I18n.backend.send(:cache_key, :foo).index('i18n')
  end

  define_method "test adds a custom cache key namespace" do
    with_cache_namespace('bar') do
      assert_equal 0, I18n.backend.send(:cache_key, :foo).index('i18n-bar')
    end
  end

  protected

    def with_cache_namespace(namespace)
      I18n.cache_namespace = namespace
      yield
      I18n.cache_namespace = nil
    end
end

end # AS cache check
