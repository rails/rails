# frozen_string_literal: true

require_relative "../../abstract_unit"
require "active_support/cache"
require_relative "../behaviors"

class MemoryStoreTest < ActiveSupport::TestCase
  def setup
    @cache = lookup_store(expires_in: 60)
  end

  def lookup_store(options = {})
    ActiveSupport::Cache.lookup_store(:memory_store, options)
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

  def test_increment_preserves_expiry
    @cache = lookup_store
    @cache.write("counter", 1, raw: true, expires_in: 30.seconds)
    assert_equal 1, @cache.read("counter", raw: true)

    Time.stub(:now, Time.now + 1.minute) do
      assert_nil @cache.read("counter", raw: true)
    end

    @cache.write("counter", 1, raw: true, expires_in: 30.seconds)
    @cache.increment("counter")
    assert_equal 2, @cache.read("counter", raw: true)
    Time.stub(:now, Time.now + 1.minute) do
      assert_nil @cache.read("counter", raw: true)
    end
  end

  def test_cleanup_instrumentation
    size = 3
    size.times { |i| @cache.write(i.to_s, i) }

    events = with_instrumentation "cleanup" do
      @cache.cleanup
    end

    assert_equal %w[cache_cleanup.active_support], events.map(&:name)
    assert_equal size, events[0].payload[:size]
    assert_equal @cache.class.name, events[0].payload[:store]
  end

  def test_nil_coder_bypasses_mutation_safeguard
    @cache = lookup_store(coder: nil)
    value = {}
    @cache.write("key", value)

    assert_same value, @cache.read("key")
  end

  def test_write_with_unless_exist
    assert_equal true, @cache.write(1, "aaaaaaaaaa")
    assert_equal false, @cache.write(1, "aaaaaaaaaa", unless_exist: true)
    @cache.write(1, nil)
    assert_equal false, @cache.write(1, "aaaaaaaaaa", unless_exist: true)
  end

  def test_namespaced_write_with_unless_exist
    namespaced_cache = lookup_store(expires_in: 60, namespace: "foo")

    assert_equal true, namespaced_cache.write(1, "aaaaaaaaaa")
    assert_equal false, namespaced_cache.write(1, "aaaaaaaaaa", unless_exist: true)
    namespaced_cache.write(1, nil)
    assert_equal false, namespaced_cache.write(1, "aaaaaaaaaa", unless_exist: true)
  end

  def test_write_expired_value_with_unless_exist
    assert_equal true, @cache.write(1, "aaaa", expires_in: 1.second)
    travel 2.seconds
    assert_equal true, @cache.write(1, "bbbb", expires_in: 1.second, unless_exist: true)
  end

  private
    def compression_always_disabled_by_default?
      true
    end
end

class MemoryStorePruningTest < ActiveSupport::TestCase
  def setup
    @record_size = ActiveSupport::Cache.lookup_store(:memory_store).send(:cached_size, 1, ActiveSupport::Cache::Entry.new("aaaaaaaaaa"))
    @cache = ActiveSupport::Cache.lookup_store(:memory_store, expires_in: 60, size: @record_size * 10 + 1)
  end

  def test_prune_size
    @cache.write(1, "aaaaaaaaaa") && sleep(0.001)
    @cache.write(2, "bbbbbbbbbb") && sleep(0.001)
    @cache.write(3, "cccccccccc") && sleep(0.001)
    @cache.write(4, "dddddddddd") && sleep(0.001)
    @cache.write(5, "eeeeeeeeee") && sleep(0.001)
    @cache.read(2) && sleep(0.001)
    @cache.read(4)
    @cache.prune(@record_size * 3)
    assert @cache.exist?(5)
    assert @cache.exist?(4)
    assert_not @cache.exist?(3), "no entry"
    assert @cache.exist?(2)
    assert_not @cache.exist?(1), "no entry"
  end

  def test_prune_size_on_write
    @cache.write(1, "aaaaaaaaaa") && sleep(0.001)
    @cache.write(2, "bbbbbbbbbb") && sleep(0.001)
    @cache.write(3, "cccccccccc") && sleep(0.001)
    @cache.write(4, "dddddddddd") && sleep(0.001)
    @cache.write(5, "eeeeeeeeee") && sleep(0.001)
    @cache.write(6, "ffffffffff") && sleep(0.001)
    @cache.write(7, "gggggggggg") && sleep(0.001)
    @cache.write(8, "hhhhhhhhhh") && sleep(0.001)
    @cache.write(9, "iiiiiiiiii") && sleep(0.001)
    @cache.write(10, "kkkkkkkkkk") && sleep(0.001)
    @cache.read(2) && sleep(0.001)
    @cache.read(4) && sleep(0.001)
    @cache.write(11, "llllllllll")
    assert @cache.exist?(11)
    assert @cache.exist?(10)
    assert @cache.exist?(9)
    assert @cache.exist?(8)
    assert @cache.exist?(7)
    assert_not @cache.exist?(6), "no entry"
    assert_not @cache.exist?(5), "no entry"
    assert @cache.exist?(4)
    assert_not @cache.exist?(3), "no entry"
    assert @cache.exist?(2)
    assert_not @cache.exist?(1), "no entry"
  end

  def test_prune_size_on_write_based_on_key_length
    @cache.write(1, "aaaaaaaaaa") && sleep(0.001)
    @cache.write(2, "bbbbbbbbbb") && sleep(0.001)
    @cache.write(3, "cccccccccc") && sleep(0.001)
    @cache.write(4, "dddddddddd") && sleep(0.001)
    @cache.write(5, "eeeeeeeeee") && sleep(0.001)
    @cache.write(6, "ffffffffff") && sleep(0.001)
    @cache.write(7, "gggggggggg") && sleep(0.001)
    @cache.write(8, "hhhhhhhhhh") && sleep(0.001)
    @cache.write(9, "iiiiiiiiii") && sleep(0.001)
    long_key = "*" * 2 * @record_size
    @cache.write(long_key, "llllllllll")
    assert @cache.exist?(long_key)
    assert @cache.exist?(9)
    assert @cache.exist?(8)
    assert @cache.exist?(7)
    assert @cache.exist?(6)
    assert_not @cache.exist?(5), "no entry"
    assert_not @cache.exist?(4), "no entry"
    assert_not @cache.exist?(3), "no entry"
    assert_not @cache.exist?(2), "no entry"
    assert_not @cache.exist?(1), "no entry"
  end

  def test_pruning_is_capped_at_a_max_time
    def @cache.delete_entry(*args, **options)
      sleep(0.01)
      super
    end
    @cache.write(1, "aaaaaaaaaa") && sleep(0.001)
    @cache.write(2, "bbbbbbbbbb") && sleep(0.001)
    @cache.write(3, "cccccccccc") && sleep(0.001)
    @cache.write(4, "dddddddddd") && sleep(0.001)
    @cache.write(5, "eeeeeeeeee") && sleep(0.001)
    @cache.prune(30, 0.001)
    assert @cache.exist?(5)
    assert @cache.exist?(4)
    assert @cache.exist?(3)
    assert @cache.exist?(2)
    assert_not @cache.exist?(1)
  end

  def test_cache_not_mutated
    item = { "foo" => "bar" }
    key = "test_key"
    @cache.write(key, item)

    read_item = @cache.read(key)
    read_item["foo"] = "xyz"
    assert_equal item, @cache.read(key)
  end

  def test_cache_different_object_ids_hash
    item = { "foo" => "bar" }
    key = "test_key"
    @cache.write(key, item)

    read_item = @cache.read(key)
    assert_not_equal item.object_id, read_item.object_id
    assert_not_equal read_item.object_id, @cache.read(key).object_id
  end

  def test_cache_different_object_ids_string
    item = "my_string"
    key = "test_key"
    @cache.write(key, item)

    read_item = @cache.read(key)
    assert_not_equal item.object_id, read_item.object_id
    assert_not_equal read_item.object_id, @cache.read(key).object_id
  end
end
