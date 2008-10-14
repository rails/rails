require 'abstract_unit'

class CacheKeyTest < Test::Unit::TestCase
  def test_expand_cache_key
    assert_equal 'name/1/2/true', ActiveSupport::Cache.expand_cache_key([1, '2', true], :name)
  end
end

class CacheStoreSettingTest < Test::Unit::TestCase
  def test_file_fragment_cache_store
    store = ActiveSupport::Cache.lookup_store :file_store, "/path/to/cache/directory"
    assert_kind_of(ActiveSupport::Cache::FileStore, store)
    assert_equal "/path/to/cache/directory", store.cache_path
  end
  
  def test_drb_fragment_cache_store
    store = ActiveSupport::Cache.lookup_store :drb_store, "druby://localhost:9192"
    assert_kind_of(ActiveSupport::Cache::DRbStore, store)
    assert_equal "druby://localhost:9192", store.address
  end

  def test_mem_cache_fragment_cache_store
    store = ActiveSupport::Cache.lookup_store :mem_cache_store, "localhost"
    assert_kind_of(ActiveSupport::Cache::MemCacheStore, store)
    assert_equal %w(localhost), store.addresses
  end
  
  def test_mem_cache_fragment_cache_store_with_multiple_servers
    store = ActiveSupport::Cache.lookup_store :mem_cache_store, "localhost", '192.168.1.1'
    assert_kind_of(ActiveSupport::Cache::MemCacheStore, store)
    assert_equal %w(localhost 192.168.1.1), store.addresses
  end
  
  def test_mem_cache_fragment_cache_store_with_options
    store = ActiveSupport::Cache.lookup_store :mem_cache_store, "localhost", '192.168.1.1', :namespace => 'foo'
    assert_kind_of(ActiveSupport::Cache::MemCacheStore, store)
    assert_equal %w(localhost 192.168.1.1), store.addresses
    assert_equal 'foo', store.instance_variable_get('@data').instance_variable_get('@namespace')
  end

  def test_object_assigned_fragment_cache_store
    store = ActiveSupport::Cache.lookup_store ActiveSupport::Cache::FileStore.new("/path/to/cache/directory")
    assert_kind_of(ActiveSupport::Cache::FileStore, store)
    assert_equal "/path/to/cache/directory", store.cache_path
  end
end

uses_mocha 'high-level cache store tests' do
  class CacheStoreTest < Test::Unit::TestCase
    def setup
      @cache = ActiveSupport::Cache.lookup_store(:memory_store)
    end

    def test_fetch_without_cache_miss
      @cache.stubs(:read).with('foo', {}).returns('bar')
      @cache.expects(:write).never
      assert_equal 'bar', @cache.fetch('foo') { 'baz' }
    end

    def test_fetch_with_cache_miss
      @cache.stubs(:read).with('foo', {}).returns(nil)
      @cache.expects(:write).with('foo', 'baz', {})
      assert_equal 'baz', @cache.fetch('foo') { 'baz' }
    end

    def test_fetch_with_forced_cache_miss
      @cache.expects(:read).never
      @cache.expects(:write).with('foo', 'bar', :force => true)
      @cache.fetch('foo', :force => true) { 'bar' }
    end
  end
end

# Tests the base functionality that should be identical across all cache stores.
module CacheStoreBehavior
  def test_should_read_and_write_strings
    @cache.write('foo', 'bar')
    assert_equal 'bar', @cache.read('foo')
  end

  def test_should_read_and_write_hash
    @cache.write('foo', {:a => "b"})
    assert_equal({:a => "b"}, @cache.read('foo'))
  end

  def test_should_read_and_write_nil
    @cache.write('foo', nil)
    assert_equal nil, @cache.read('foo')
  end

  def test_fetch_without_cache_miss
    @cache.write('foo', 'bar')
    assert_equal 'bar', @cache.fetch('foo') { 'baz' }
  end

  def test_fetch_with_cache_miss
    assert_equal 'baz', @cache.fetch('foo') { 'baz' }
  end

  def test_fetch_with_forced_cache_miss
    @cache.fetch('foo', :force => true) { 'bar' }
  end

  def test_increment
    @cache.write('foo', 1, :raw => true)
    assert_equal 1, @cache.read('foo', :raw => true).to_i
    assert_equal 2, @cache.increment('foo')
    assert_equal 2, @cache.read('foo', :raw => true).to_i
    assert_equal 3, @cache.increment('foo')
    assert_equal 3, @cache.read('foo', :raw => true).to_i
  end

  def test_decrement
    @cache.write('foo', 3, :raw => true)
    assert_equal 3, @cache.read('foo', :raw => true).to_i
    assert_equal 2, @cache.decrement('foo')
    assert_equal 2, @cache.read('foo', :raw => true).to_i
    assert_equal 1, @cache.decrement('foo')
    assert_equal 1, @cache.read('foo', :raw => true).to_i
  end
end

class FileStoreTest < Test::Unit::TestCase
  def setup
    @cache = ActiveSupport::Cache.lookup_store(:file_store, Dir.pwd)
  end

  def teardown
    File.delete("foo.cache")
  end

  include CacheStoreBehavior
end

class MemoryStoreTest < Test::Unit::TestCase
  def setup
    @cache = ActiveSupport::Cache.lookup_store(:memory_store)
  end

  include CacheStoreBehavior

  def test_store_objects_should_be_immutable
    @cache.write('foo', 'bar')
    assert_raise(ActiveSupport::FrozenObjectError) { @cache.read('foo').gsub!(/.*/, 'baz') }
    assert_equal 'bar', @cache.read('foo')
  end
end

uses_memcached 'memcached backed store' do
  class MemCacheStoreTest < Test::Unit::TestCase
    def setup
      @cache = ActiveSupport::Cache.lookup_store(:mem_cache_store)
      @cache.clear
    end

    include CacheStoreBehavior

    def test_store_objects_should_be_immutable
      @cache.write('foo', 'bar')
      @cache.read('foo').gsub!(/.*/, 'baz')
      assert_equal 'bar', @cache.read('foo')
    end
  end

  class CompressedMemCacheStore < Test::Unit::TestCase
    def setup
      @cache = ActiveSupport::Cache.lookup_store(:compressed_mem_cache_store)
      @cache.clear
    end

    include CacheStoreBehavior
  end
end
