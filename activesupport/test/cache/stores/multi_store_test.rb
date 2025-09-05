# frozen_string_literal: true

require_relative "../../abstract_unit"
require "active_support/cache"
require_relative "../behaviors"

class MultiStoreTest < ActiveSupport::TestCase
  def setup
    # Initialize MultiStore with the underlying stores
    @cache = lookup_store(expires_in: 60)
  end

  def lookup_store(options = {})
    @l1_store = ActiveSupport::Cache.lookup_store(:memory_store, options)
    @l2_store = ActiveSupport::Cache.lookup_store(:memory_store, options)

    ActiveSupport::Cache.lookup_store(:multi_store, @l1_store, @l2_store)
  end

  def teardown
    @cache.clear
  end

  include CacheStoreBehavior
  include CacheStoreVersionBehavior
  include CacheStoreCoderBehavior
  include CacheStoreCompressionBehavior
  include CacheStoreSerializerBehavior
  include CacheDeleteMatchedBehavior
  include CacheIncrementDecrementBehavior
  include CacheInstrumentationBehavior
  include CacheLoggingBehavior

  def test_read_from_first_level
    @l1_store.write('foo', 'bar')
    assert_equal 'bar', @cache.read('foo')
  end

  def test_read_promotes_entry_to_higher_levels
    @l2_store.write('foo', 'bar')
    assert_nil @l1_store.read('foo')

    assert_equal 'bar', @cache.read('foo')
    assert_equal 'bar', @l1_store.read('foo'), 'Entry should be promoted to L1 store'
  end

  def test_write_writes_to_all_levels
    @cache.write('foo', 'bar')
    assert_equal 'bar', @l1_store.read('foo')
    assert_equal 'bar', @l2_store.read('foo')
  end

  def test_delete_deletes_from_all_levels
    @cache.write('foo', 'bar')
    @cache.delete('foo')
    assert_nil @l1_store.read('foo')
    assert_nil @l2_store.read('foo')
  end

  def test_increment
    @cache.write('counter', 1, raw: true)
    @cache.increment('counter')
    assert_equal 2, @cache.read('counter', raw: true)
    assert_equal 2, @l1_store.read('counter', raw: true)
    assert_equal 2, @l2_store.read('counter', raw: true)
  end

  def test_decrement
    @cache.write('counter', 3, raw: true)
    @cache.decrement('counter')
    assert_equal 2, @cache.read('counter', raw: true)
    assert_equal 2, @l1_store.read('counter', raw: true)
    assert_equal 2, @l2_store.read('counter', raw: true)
  end

  def test_clear_clears_all_levels
    @cache.write('foo', 'bar')
    @cache.clear
    assert_nil @l1_store.read('foo')
    assert_nil @l2_store.read('foo')
  end

  def test_cleanup
    @cache.write('foo', 'bar', expires_in: 1.second)
    travel 2.seconds
    @cache.cleanup
    assert_nil @l1_store.read('foo')
    assert_nil @l2_store.read('foo')
  end

  def test_delete_matched
    @cache.write('foo1', 'bar')
    @cache.write('foo2', 'baz')
    @cache.delete_matched(/^foo/)
    assert_nil @l1_store.read('foo1')
    assert_nil @l1_store.read('foo2')
    assert_nil @l2_store.read('foo1')
    assert_nil @l2_store.read('foo2')
  end

  def test_exist_checks_all_levels
    @l2_store.write('foo', 'bar')
    assert @cache.exist?('foo')
  end

  def test_fetch_writes_to_all_levels_on_miss
    value = @cache.fetch('foo') { 'bar' }
    assert_equal 'bar', value
    assert_equal 'bar', @l1_store.read('foo')
    assert_equal 'bar', @l2_store.read('foo')
  end

  def test_initialization_with_various_configs
    cache1 = ActiveSupport::Cache::MultiStore.new([
      [:memory_store, { size: 32.megabytes }],
      [:file_store, Dir.mktmpdir]
    ])
    assert_instance_of ActiveSupport::Cache::MultiStore, cache1

    cache2 = ActiveSupport::Cache::MultiStore.new(
      ActiveSupport::Cache::MemoryStore.new,
      [:file_store, Dir.mktmpdir]
    )
    assert_instance_of ActiveSupport::Cache::MultiStore, cache2

    cache3 = ActiveSupport::Cache::MultiStore.new(
      [:memory_store, { size: 32.megabytes }],
      [:file_store, Dir.mktmpdir],
      compress: true
    )
    assert_instance_of ActiveSupport::Cache::MultiStore, cache3
  end

  def test_initialization_with_options_is_passed_to_all_stores
    cache = ActiveSupport::Cache::MultiStore.new(
      [:memory_store, { size: 32.megabytes }],
      [:file_store, Dir.mktmpdir],
      compress: true
    )

    assert cache.instance_variable_get(:@stores).all? { |store| store.options[:compress] }
  end

  def test_read_multi_promotes_entries
    @l2_store.write('foo', 'bar')
    @l2_store.write('baz', 'qux')
    result = @cache.read_multi('foo', 'baz')
    assert_equal({ 'foo' => 'bar', 'baz' => 'qux' }, result)
    assert_equal 'bar', @l1_store.read('foo')
    assert_equal 'qux', @l1_store.read('baz')
  end

  def test_write_multi_writes_to_all_levels
    entries = { 'foo' => 'bar', 'baz' => 'qux' }
    @cache.write_multi(entries)
    assert_equal 'bar', @l1_store.read('foo')
    assert_equal 'qux', @l1_store.read('baz')
    assert_equal 'bar', @l2_store.read('foo')
    assert_equal 'qux', @l2_store.read('baz')
  end

  def test_fetch_multi_promotes_entries
    @l2_store.write('foo', 'bar')
    result = @cache.fetch_multi('foo', 'baz') { |key| "#{key}_value" }
    expected = { 'foo' => 'bar', 'baz' => 'baz_value' }
    assert_equal expected, result
    assert_equal 'bar', @l1_store.read('foo')
    assert_equal 'baz_value', @l1_store.read('baz')
  end

  def test_expiration_across_levels
    @cache.write('foo', 'bar', expires_in: 1.second)
    travel 2.seconds
    assert_nil @cache.read('foo')
    assert_nil @l1_store.read('foo')
    assert_nil @l2_store.read('foo')
  end

  def test_write_with_unless_exist
    @cache.write('foo', 'bar')
    result = @cache.write('foo', 'baz', unless_exist: true)
    assert_not result
    assert_equal 'bar', @cache.read('foo')
  end

  def test_coder_receive_the_entry_on_write
    coder = SpyCoder.new
    @store = lookup_store(coder: coder)
    @store.write("foo", "bar")
    assert_equal 2, coder.dumped_entries.size
    entry = coder.dumped_entries.first
    assert_instance_of ActiveSupport::Cache::Entry, entry
    assert_equal "bar", entry.value
  end

  def test_coder_receive_the_entry_on_write_multi
    coder = SpyCoder.new
    @store = lookup_store(coder: coder)
    @store.write_multi({ "foo" => "bar", "egg" => "spam" })
    assert_equal 4, coder.dumped_entries.size
    entry = coder.dumped_entries.first
    assert_instance_of ActiveSupport::Cache::Entry, entry
    assert_equal "bar", entry.value

    entry = coder.dumped_entries[1]
    assert_instance_of ActiveSupport::Cache::Entry, entry
    assert_equal "spam", entry.value
  end

  def test_coder_is_used_during_handle_expired_entry_when_expired
    coder = SpyCoder.new
    @store = lookup_store(coder: coder)
    @store.write("foo", "bar", expires_in: 1.second)
    assert_equal 0, coder.loaded_entries.size
    assert_equal 2, coder.dumped_entries.size

    travel_to(2.seconds.from_now) do
      val = @store.fetch(
          "foo",
          race_condition_ttl: 5,
          compress: true,
          compress_threshold: 0
        ) { "baz" }
      assert_equal "baz", val
      assert_equal 1, coder.loaded_entries.size # 1 read in fetch
      assert_equal "bar", coder.loaded_entries.first.value
      assert_equal 2, coder.dumped_entries.size # did not change from original write
      assert_equal 4, coder.dump_compressed_entries.size # 1 write the expired entry handler, 1 in fetch
      assert_equal "bar", coder.dump_compressed_entries.first.value
      assert_equal "baz", coder.dump_compressed_entries.last.value
    end
  end

  def test_increment_instrumentation
    key_1 = SecureRandom.uuid
    @cache.write(key_1, 0)

    events = capture_notifications("cache_increment.active_support") { @cache.increment(key_1) }

    assert_equal %w[ cache_increment.active_support cache_increment.active_support ], events.map(&:name)
    assert_equal normalized_key(key_1), events[0].payload[:key]
    assert_equal normalized_key(key_1), events[1].payload[:key]
    assert_equal @l1_store.class.name, events[0].payload[:store]
    assert_equal @l2_store.class.name, events[1].payload[:store]
  end

  def test_decrement_instrumentation
    key_1 = SecureRandom.uuid
    @cache.write(key_1, 0)

    events = capture_notifications("cache_decrement.active_support") { @cache.decrement(key_1) }

    assert_equal %w[ cache_decrement.active_support cache_decrement.active_support ], events.map(&:name)
    assert_equal normalized_key(key_1), events[0].payload[:key]
    assert_equal normalized_key(key_1), events[1].payload[:key]
    assert_equal @l1_store.class.name, events[0].payload[:store]
    assert_equal @l2_store.class.name, events[1].payload[:store]
  end

  private
    def compression_always_disabled_by_default?
      true
    end
end

# Patch MultiStore with test-only serialization methods.
# CacheStoreCompressionBehavior tests call serialize_entry directly to measure
# compression effectiveness. MultiStore doesn't serialize entries itself - it
# passes Entry objects to underlying stores which handle their own serialization.
# These methods delegate to the first store to satisfy the test requirements.
ActiveSupport::Cache::MultiStore.class_eval do
  protected

  def serialize_entry(entry, **options)
    @stores.first.send(:serialize_entry, entry, **options)
  end

  def deserialize_entry(payload, **options)
    @stores.first.send(:deserialize_entry, payload, **options)
  end
end
