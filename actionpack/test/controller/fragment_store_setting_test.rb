require File.dirname(__FILE__) + '/../abstract_unit'

MemCache = Struct.new(:MemCache, :address) unless Object.const_defined?(:MemCache)

class FragmentCacheStoreSettingTest < Test::Unit::TestCase
  def teardown
    ActionController::Base.fragment_cache_store = ActionController::Caching::Fragments::MemoryStore.new
  end
  
  def test_file_fragment_cache_store
    ActionController::Base.fragment_cache_store = :file_store, "/path/to/cache/directory"
    assert_kind_of(
      ActionController::Caching::Fragments::FileStore,
      ActionController::Base.fragment_cache_store
    )
    assert_equal "/path/to/cache/directory", ActionController::Base.fragment_cache_store.cache_path
  end
  
  def test_drb_fragment_cache_store
    ActionController::Base.fragment_cache_store = :drb_store, "druby://localhost:9192"
    assert_kind_of(
      ActionController::Caching::Fragments::DRbStore,
      ActionController::Base.fragment_cache_store
    )
    assert_equal "druby://localhost:9192", ActionController::Base.fragment_cache_store.address
  end
  
  def test_mem_cache_fragment_cache_store
    ActionController::Base.fragment_cache_store = :mem_cache_store, "localhost"
    assert_kind_of(
      ActionController::Caching::Fragments::MemCacheStore,
      ActionController::Base.fragment_cache_store
    )
    assert_equal %w(localhost), ActionController::Base.fragment_cache_store.addresses
  end

  def test_object_assigned_fragment_cache_store
    ActionController::Base.fragment_cache_store = ActionController::Caching::Fragments::FileStore.new("/path/to/cache/directory")
    assert_kind_of(
      ActionController::Caching::Fragments::FileStore,
      ActionController::Base.fragment_cache_store
    )
    assert_equal "/path/to/cache/directory", ActionController::Base.fragment_cache_store.cache_path
  end
end
