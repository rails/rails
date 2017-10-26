# frozen_string_literal: true

require "abstract_unit"
require "active_support/cache"
require_relative "../behaviors"
require "pathname"

class FileStoreTest < ActiveSupport::TestCase
  def setup
    Dir.mkdir(cache_dir) unless File.exist?(cache_dir)
    @cache = ActiveSupport::Cache.lookup_store(:file_store, cache_dir, expires_in: 60)
    @peek = ActiveSupport::Cache.lookup_store(:file_store, cache_dir, expires_in: 60)
    @cache_with_pathname = ActiveSupport::Cache.lookup_store(:file_store, Pathname.new(cache_dir), expires_in: 60)

    @buffer = StringIO.new
    @cache.logger = ActiveSupport::Logger.new(@buffer)
  end

  def teardown
    FileUtils.rm_r(cache_dir)
  rescue Errno::ENOENT
  end

  def cache_dir
    File.join(Dir.pwd, "tmp_cache")
  end

  include CacheStoreBehavior
  include CacheStoreVersionBehavior
  include LocalCacheBehavior
  include CacheDeleteMatchedBehavior
  include CacheIncrementDecrementBehavior
  include AutoloadingCacheBehavior

  def test_clear
    gitkeep = File.join(cache_dir, ".gitkeep")
    keep = File.join(cache_dir, ".keep")
    FileUtils.touch([gitkeep, keep])
    @cache.clear
    assert File.exist?(gitkeep)
    assert File.exist?(keep)
  end

  def test_clear_without_cache_dir
    FileUtils.rm_r(cache_dir)
    @cache.clear
  end

  def test_long_uri_encoded_keys
    @cache.write("%" * 870, 1)
    assert_equal 1, @cache.read("%" * 870)
  end

  def test_key_transformation
    key = @cache.send(:normalize_key, "views/index?id=1", {})
    assert_equal "views/index?id=1", @cache.send(:file_path_key, key)
  end

  def test_key_transformation_with_pathname
    FileUtils.touch(File.join(cache_dir, "foo"))
    key = @cache_with_pathname.send(:normalize_key, "views/index?id=1", {})
    assert_equal "views/index?id=1", @cache_with_pathname.send(:file_path_key, key)
  end

  # Test that generated cache keys are short enough to have Tempfile stuff added to them and
  # remain valid
  def test_filename_max_size
    key = "#{'A' * ActiveSupport::Cache::FileStore::FILENAME_MAX_SIZE}"
    path = @cache.send(:normalize_key, key, {})
    Dir::Tmpname.create(path) do |tmpname, n, opts|
      assert File.basename(tmpname + ".lock").length <= 255, "Temp filename too long: #{File.basename(tmpname + '.lock').length}"
    end
  end

  # Because file systems have a maximum filename size, filenames > max size should be split in to directories
  # If filename is 'AAAAB', where max size is 4, the returned path should be AAAA/B
  def test_key_transformation_max_filename_size
    key = "#{'A' * ActiveSupport::Cache::FileStore::FILENAME_MAX_SIZE}B"
    path = @cache.send(:normalize_key, key, {})
    assert path.split("/").all? { |dir_name| dir_name.size <= ActiveSupport::Cache::FileStore::FILENAME_MAX_SIZE }
    assert_equal "B", File.basename(path)
  end

  # If nothing has been stored in the cache, there is a chance the cache directory does not yet exist
  # Ensure delete_matched gracefully handles this case
  def test_delete_matched_when_cache_directory_does_not_exist
    assert_nothing_raised do
      ActiveSupport::Cache::FileStore.new("/test/cache/directory").delete_matched(/does_not_exist/)
    end
  end

  def test_delete_does_not_delete_empty_parent_dir
    sub_cache_dir = File.join(cache_dir, "subdir/")
    sub_cache_store = ActiveSupport::Cache::FileStore.new(sub_cache_dir)
    assert_nothing_raised do
      assert sub_cache_store.write("foo", "bar")
      assert sub_cache_store.delete("foo")
    end
    assert File.exist?(cache_dir), "Parent of top level cache dir was deleted!"
    assert File.exist?(sub_cache_dir), "Top level cache dir was deleted!"
    assert Dir.entries(sub_cache_dir).reject { |f| ActiveSupport::Cache::FileStore::EXCLUDED_DIRS.include?(f) }.empty?
  end

  def test_log_exception_when_cache_read_fails
    File.stub(:exist?, -> { raise StandardError.new("failed") }) do
      @cache.send(:read_entry, "winston", {})
      assert @buffer.string.present?
    end
  end

  def test_cleanup_removes_all_expired_entries
    time = Time.now
    @cache.write("foo", "bar", expires_in: 10)
    @cache.write("baz", "qux")
    @cache.write("quux", "corge", expires_in: 20)
    Time.stub(:now, time + 15) do
      @cache.cleanup
      assert_not @cache.exist?("foo")
      assert @cache.exist?("baz")
      assert @cache.exist?("quux")
      assert_equal 2, Dir.glob(File.join(cache_dir, "**")).size
    end
  end

  def test_write_with_unless_exist
    assert_equal true, @cache.write(1, "aaaaaaaaaa")
    assert_equal false, @cache.write(1, "aaaaaaaaaa", unless_exist: true)
    @cache.write(1, nil)
    assert_equal false, @cache.write(1, "aaaaaaaaaa", unless_exist: true)
  end
end
