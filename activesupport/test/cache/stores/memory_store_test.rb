# frozen_string_literal: true

require "abstract_unit"
require "active_support/cache"
require_relative "../behaviors"

class MemoryStoreTest < ActiveSupport::TestCase
  def setup
    @record_size = ActiveSupport::Cache.lookup_store(:memory_store).send(:cached_size, 1, ActiveSupport::Cache::Entry.new("aaaaaaaaaa"))
    @cache = ActiveSupport::Cache.lookup_store(:memory_store, expires_in: 60, size: @record_size * 10 + 1)
  end

  include CacheStoreBehavior
  include CacheStoreVersionBehavior
  include CacheDeleteMatchedBehavior
  include CacheIncrementDecrementBehavior
  include CacheInstrumentationBehavior

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
    assert !@cache.exist?(3), "no entry"
    assert @cache.exist?(2)
    assert !@cache.exist?(1), "no entry"
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
    assert !@cache.exist?(6), "no entry"
    assert !@cache.exist?(5), "no entry"
    assert @cache.exist?(4)
    assert !@cache.exist?(3), "no entry"
    assert @cache.exist?(2)
    assert !@cache.exist?(1), "no entry"
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
    assert !@cache.exist?(5), "no entry"
    assert !@cache.exist?(4), "no entry"
    assert !@cache.exist?(3), "no entry"
    assert !@cache.exist?(2), "no entry"
    assert !@cache.exist?(1), "no entry"
  end

  def test_pruning_is_capped_at_a_max_time
    def @cache.delete_entry(*args)
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
    assert !@cache.exist?(1)
  end

  def test_write_with_unless_exist
    assert_equal true, @cache.write(1, "aaaaaaaaaa")
    assert_equal false, @cache.write(1, "aaaaaaaaaa", unless_exist: true)
    @cache.write(1, nil)
    assert_equal false, @cache.write(1, "aaaaaaaaaa", unless_exist: true)
  end
end
