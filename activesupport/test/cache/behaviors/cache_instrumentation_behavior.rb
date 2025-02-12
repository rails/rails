# frozen_string_literal: true

module CacheInstrumentationBehavior
  def test_write_multi_instrumentation
    key_1 = SecureRandom.uuid
    key_2 = SecureRandom.uuid
    value_1 = SecureRandom.alphanumeric
    value_2 = SecureRandom.alphanumeric
    writes = { key_1 => value_1, key_2 => value_2 }

    events = capture_notifications("cache_write_multi.active_support") { @cache.write_multi(writes) }

    assert_equal %w[ cache_write_multi.active_support ], events.map(&:name)
    assert_nil events[0].payload[:super_operation]
    assert_equal({ normalized_key(key_1) => value_1, normalized_key(key_2) => value_2 }, events[0].payload[:key])
  end

  def test_instrumentation_with_fetch_multi_as_super_operation
    key_1 = SecureRandom.uuid
    @cache.write(key_1, SecureRandom.alphanumeric)

    key_2 = SecureRandom.uuid

    events = capture_notifications("cache_read_multi.active_support") do
      @cache.fetch_multi(key_2, key_1) { |key| key * 2 }
    end

    assert_equal %w[ cache_read_multi.active_support ], events.map(&:name)
    assert_equal :fetch_multi, events[0].payload[:super_operation]
    assert_equal [normalized_key(key_2), normalized_key(key_1)], events[0].payload[:key]
    assert_equal [normalized_key(key_1)], events[0].payload[:hits]
    assert_equal @cache.class.name, events[0].payload[:store]
  end

  def test_fetch_multi_instrumentation_order_of_operations
    key_1 = SecureRandom.uuid
    key_2 = SecureRandom.uuid

    operations = capture_notifications(/^cache_(read_multi|write_multi)\.active_support$/) do
      @cache.fetch_multi(key_1, key_2) { |key| key * 2 }
    end

    assert_equal %w[ cache_read_multi.active_support cache_write_multi.active_support ], operations.map(&:name)
  end

  def test_read_multi_instrumentation
    key_1 = SecureRandom.uuid
    @cache.write(key_1, SecureRandom.alphanumeric)

    key_2 = SecureRandom.uuid

    events = capture_notifications("cache_read_multi.active_support") { @cache.read_multi(key_2, key_1) }

    assert_equal %w[ cache_read_multi.active_support ], events.map(&:name)
    assert_equal [normalized_key(key_2), normalized_key(key_1)], events[0].payload[:key]
    assert_equal [normalized_key(key_1)], events[0].payload[:hits]
    assert_equal @cache.class.name, events[0].payload[:store]
  end

  def test_read_instrumentation
    key = SecureRandom.uuid
    @cache.write(key, SecureRandom.alphanumeric)

    events = capture_notifications("cache_read.active_support") { @cache.read(key) }

    assert_equal %w[ cache_read.active_support ], events.map(&:name)
    assert_equal normalized_key(key), events[0].payload[:key]
    assert_same true, events[0].payload[:hit]
    assert_equal @cache.class.name, events[0].payload[:store]
  end

  def test_write_instrumentation
    key = SecureRandom.uuid

    events = capture_notifications("cache_write.active_support") { @cache.write(key, SecureRandom.alphanumeric) }

    assert_equal %w[ cache_write.active_support ], events.map(&:name)
    assert_equal normalized_key(key), events[0].payload[:key]
    assert_equal @cache.class.name, events[0].payload[:store]
  end

  def test_delete_instrumentation
    key = SecureRandom.uuid

    options = { namespace: "foo" }

    events = capture_notifications("cache_delete.active_support") { @cache.delete(key, options) }

    assert_equal %w[ cache_delete.active_support ], events.map(&:name)
    assert_equal normalized_key(key, options), events[0].payload[:key]
    assert_equal @cache.class.name, events[0].payload[:store]
    assert_equal "foo", events[0].payload[:namespace]
  end

  def test_delete_multi_instrumentation
    key_1 = SecureRandom.uuid
    key_2 = SecureRandom.uuid

    options = { namespace: "foo" }

    events = capture_notifications("cache_delete_multi.active_support") { @cache.delete_multi([key_2, key_1], options) }

    assert_equal %w[ cache_delete_multi.active_support ], events.map(&:name)
    assert_equal [normalized_key(key_2, options), normalized_key(key_1, options)], events[0].payload[:key]
    assert_equal @cache.class.name, events[0].payload[:store]
  end

  def test_increment_instrumentation
    key_1 = SecureRandom.uuid
    @cache.write(key_1, 0)

    events = capture_notifications("cache_increment.active_support") { @cache.increment(key_1) }

    assert_equal %w[ cache_increment.active_support ], events.map(&:name)
    assert_equal normalized_key(key_1), events[0].payload[:key]
    assert_equal @cache.class.name, events[0].payload[:store]
  end


  def test_decrement_instrumentation
    key_1 = SecureRandom.uuid
    @cache.write(key_1, 0)

    events = capture_notifications("cache_decrement.active_support") { @cache.decrement(key_1) }

    assert_equal %w[ cache_decrement.active_support ], events.map(&:name)
    assert_equal normalized_key(key_1), events[0].payload[:key]
    assert_equal @cache.class.name, events[0].payload[:store]
  end

  private
    def normalized_key(key, options = nil)
      @cache.send(:normalize_key, key, options)
    end
end
