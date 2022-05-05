# frozen_string_literal: true

module LocalCacheBehavior
  def test_instrumentation_with_local_cache
    key = SecureRandom.uuid
    events = with_instrumentation "write" do
      @cache.write(key, SecureRandom.uuid)
    end
    assert_equal @cache.class.name, events[0].payload[:store]

    @cache.with_local_cache do
      events = with_instrumentation "read" do
        @cache.read(key)
        @cache.read(key)
      end

      expected = [@cache.class.name, @cache.send(:local_cache).class.name]
      assert_equal expected, events.map { |p| p.payload[:store] }
    end
  end

  def test_local_writes_are_persistent_on_the_remote_cache
    key = SecureRandom.uuid
    value = SecureRandom.alphanumeric
    retval = @cache.with_local_cache do
      @cache.write(key, value)
    end
    assert retval
    assert_equal value, @cache.read(key)
  end

  def test_clear_also_clears_local_cache
    key = SecureRandom.uuid
    @cache.with_local_cache do
      @cache.write(key, SecureRandom.alphanumeric)
      @cache.clear
      assert_nil @cache.read(key)
    end

    assert_nil @cache.read(key)
  end

  def test_cleanup_clears_local_cache_but_not_remote_cache
    begin
      @cache.cleanup
    rescue NotImplementedError
      skip
    end

    key = SecureRandom.uuid
    value = SecureRandom.alphanumeric
    other_value = SecureRandom.alphanumeric

    @cache.with_local_cache do
      @cache.write(key, value)
      assert_equal value, @cache.read(key)

      @cache.send(:bypass_local_cache) { @cache.write(key, other_value) }
      assert_equal value, @cache.read(key)

      @cache.cleanup
      assert_equal other_value, @cache.read(key)
    end
  end

  def test_local_cache_of_write
    key = SecureRandom.uuid
    value = SecureRandom.alphanumeric
    @cache.with_local_cache do
      @cache.write(key, value)
      @peek.delete(key)
      assert_equal value, @cache.read(key)
    end
  end

  def test_local_cache_of_read_returns_a_copy_of_the_entry
    key = SecureRandom.alphanumeric.to_sym
    value = SecureRandom.alphanumeric
    @cache.with_local_cache do
      @cache.write(key, type: value)
      local_value = @cache.read(key)
      assert_equal(value, local_value.delete(:type))
      assert_equal({ type: value }, @cache.read(key))
    end
  end

  def test_local_cache_of_read
    key = SecureRandom.uuid
    value = SecureRandom.alphanumeric
    @cache.write(key, value)
    @cache.with_local_cache do
      assert_equal value, @cache.read(key)
    end
  end

  def test_local_cache_of_read_nil
    key = SecureRandom.uuid
    value = SecureRandom.alphanumeric
    @cache.with_local_cache do
      assert_nil @cache.read(key)
      @cache.send(:bypass_local_cache) { @cache.write(key, value) }
      assert_nil @cache.read(key)
    end
  end

  def test_local_cache_fetch
    key = SecureRandom.uuid
    value = SecureRandom.alphanumeric
    @cache.with_local_cache do
      @cache.send(:local_cache).write_entry(key, value)
      assert_equal value, @cache.send(:local_cache).fetch_entry(key)
    end
  end

  def test_local_cache_of_write_nil
    key = SecureRandom.uuid
    value = SecureRandom.alphanumeric
    @cache.with_local_cache do
      assert @cache.write(key, nil)
      assert_nil @cache.read(key)
      @peek.write(key, value)
      assert_nil @cache.read(key)
    end
  end

  def test_local_cache_of_write_with_unless_exist
    key = SecureRandom.uuid
    value = SecureRandom.alphanumeric
    @cache.with_local_cache do
      @cache.write(key, value)
      @cache.write(key, SecureRandom.alphanumeric, unless_exist: true)
      assert_equal @peek.read(key), @cache.read(key)
    end
  end

  def test_local_cache_of_delete
    key = SecureRandom.uuid
    @cache.with_local_cache do
      @cache.write(key, SecureRandom.alphanumeric)
      @cache.delete(key)
      assert_nil @cache.read(key)
    end
  end

  def test_local_cache_of_delete_matched
    begin
      @cache.delete_matched("*")
    rescue NotImplementedError
      skip
    end

    prefix = SecureRandom.alphanumeric
    key = "#{prefix}#{SecureRandom.uuid}"
    other_key = "#{prefix}#{SecureRandom.uuid}"
    third_key = SecureRandom.uuid
    value = SecureRandom.alphanumeric
    @cache.with_local_cache do
      @cache.write(key, SecureRandom.alphanumeric)
      @cache.write(other_key, SecureRandom.alphanumeric)
      @cache.write(third_key, value)
      @cache.delete_matched("#{prefix}*")
      assert_not @cache.exist?(key)
      assert_not @cache.exist?(other_key)
      assert_equal value, @cache.read(third_key)
    end
  end

  def test_local_cache_of_exist
    key = SecureRandom.uuid
    @cache.with_local_cache do
      @cache.write(key, SecureRandom.alphanumeric)
      @peek.delete(key)
      assert @cache.exist?(key)
    end
  end

  def test_local_cache_of_increment
    key = SecureRandom.uuid
    @cache.with_local_cache do
      @cache.write(key, 1, raw: true)
      @peek.write(key, 2, raw: true)
      @cache.increment(key)

      expected = @peek.read(key, raw: true)
      assert_equal 3, Integer(expected)
      assert_equal expected, @cache.read(key, raw: true)
    end
  end

  def test_local_cache_of_decrement
    key = SecureRandom.uuid
    @cache.with_local_cache do
      @cache.write(key, 1, raw: true)
      @peek.write(key, 3, raw: true)

      @cache.decrement(key)
      expected = @peek.read(key, raw: true)
      assert_equal 2, Integer(expected)
      assert_equal expected, @cache.read(key, raw: true)
    end
  end

  def test_local_cache_of_fetch_multi
    key = SecureRandom.uuid
    other_key = SecureRandom.uuid
    @cache.with_local_cache do
      @cache.fetch_multi(key, other_key) { |_key| true }
      @peek.delete(key)
      @peek.delete(other_key)
      assert_equal true, @cache.read(key)
      assert_equal true, @cache.read(other_key)
    end
  end

  def test_local_cache_of_read_multi
    key = SecureRandom.uuid
    value = SecureRandom.alphanumeric
    other_key = SecureRandom.uuid
    other_value = SecureRandom.alphanumeric
    @cache.with_local_cache do
      @cache.write(key, value, raw: true)
      @cache.write(other_key, other_value, raw: true)
      values = @cache.read_multi(key, other_key, raw: true)
      assert_equal value, @cache.read(key, raw: true)
      assert_equal other_value, @cache.read(other_key, raw: true)
      assert_equal value, values[key]
      assert_equal other_value, values[other_key]
    end
  end

  def test_initial_object_mutation_after_write
    key = SecureRandom.uuid
    @cache.with_local_cache do
      initial = +"bar"
      @cache.write(key, initial)
      initial << "baz"
      assert_equal "bar", @cache.read(key)
    end
  end

  def test_initial_object_mutation_after_fetch
    key = SecureRandom.uuid
    @cache.with_local_cache do
      initial = +"bar"
      @cache.fetch(key) { initial }
      initial << "baz"
      assert_equal "bar", @cache.read(key)
      assert_equal "bar", @cache.fetch(key)
    end
  end

  def test_middleware
    key = SecureRandom.uuid
    value = SecureRandom.alphanumeric
    app = lambda { |env|
      result = @cache.write(key, value)
      assert_equal value, @cache.read(key) # make sure 'foo' was written
      assert result
      [200, {}, []]
    }
    app = @cache.middleware.new(app)
    app.call({})
  end

  def test_local_race_condition_protection
    key = SecureRandom.uuid
    value = SecureRandom.alphanumeric
    other_value = SecureRandom.alphanumeric
    @cache.with_local_cache do
      time = Time.now
      @cache.write(key, value, expires_in: 60)
      Time.stub(:now, time + 61) do
        result = @cache.fetch(key, race_condition_ttl: 10) do
          assert_equal value, @cache.read(key)
          other_value
        end
        assert_equal other_value, result
      end
    end
  end

  def test_local_cache_should_read_and_write_false
    key = SecureRandom.uuid
    @cache.with_local_cache do
      assert @cache.write(key, false)
      assert_equal false, @cache.read(key)
    end
  end

  def test_local_cache_should_deserialize_entries_on_multi_get
    keys = Array.new(5) { SecureRandom.uuid }
    values = keys.index_with(true)
    @cache.with_local_cache do
      assert @cache.write_multi(values)
      assert_equal values, @cache.read_multi(*keys)
    end
  end
end
