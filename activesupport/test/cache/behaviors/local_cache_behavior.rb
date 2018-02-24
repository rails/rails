# frozen_string_literal: true

module LocalCacheBehavior
  def test_local_writes_are_persistent_on_the_remote_cache
    retval = @cache.with_local_cache do
      @cache.write("foo", "bar")
    end
    assert retval
    assert_equal "bar", @cache.read("foo")
  end

  def test_clear_also_clears_local_cache
    @cache.with_local_cache do
      @cache.write("foo", "bar")
      @cache.clear
      assert_nil @cache.read("foo")
    end

    assert_nil @cache.read("foo")
  end

  def test_cleanup_clears_local_cache_but_not_remote_cache
    begin
      @cache.cleanup
    rescue NotImplementedError
      skip
    end

    @cache.with_local_cache do
      @cache.write("foo", "bar")
      assert_equal "bar", @cache.read("foo")

      @cache.send(:bypass_local_cache) { @cache.write("foo", "baz") }
      assert_equal "bar", @cache.read("foo")

      @cache.cleanup
      assert_equal "baz", @cache.read("foo")
    end
  end

  def test_local_cache_of_write
    @cache.with_local_cache do
      @cache.write("foo", "bar")
      @peek.delete("foo")
      assert_equal "bar", @cache.read("foo")
    end
  end

  def test_local_cache_of_read
    @cache.write("foo", "bar")
    @cache.with_local_cache do
      assert_equal "bar", @cache.read("foo")
    end
  end

  def test_local_cache_of_read_nil
    @cache.with_local_cache do
      assert_nil @cache.read("foo")
      @cache.send(:bypass_local_cache) { @cache.write "foo", "bar" }
      assert_nil @cache.read("foo")
    end
  end

  def test_local_cache_fetch
    @cache.with_local_cache do
      @cache.send(:local_cache).write "foo", "bar"
      assert_equal "bar", @cache.send(:local_cache).fetch("foo")
    end
  end

  def test_local_cache_of_write_nil
    @cache.with_local_cache do
      assert @cache.write("foo", nil)
      assert_nil @cache.read("foo")
      @peek.write("foo", "bar")
      assert_nil @cache.read("foo")
    end
  end

  def test_local_cache_of_write_with_unless_exist
    @cache.with_local_cache do
      @cache.write("foo", "bar")
      @cache.write("foo", "baz", unless_exist: true)
      assert_equal @peek.read("foo"), @cache.read("foo")
    end
  end

  def test_local_cache_of_delete
    @cache.with_local_cache do
      @cache.write("foo", "bar")
      @cache.delete("foo")
      assert_nil @cache.read("foo")
    end
  end

  def test_local_cache_of_exist
    @cache.with_local_cache do
      @cache.write("foo", "bar")
      @peek.delete("foo")
      assert @cache.exist?("foo")
    end
  end

  def test_local_cache_of_increment
    @cache.with_local_cache do
      @cache.write("foo", 1, raw: true)
      @peek.write("foo", 2, raw: true)
      @cache.increment("foo")
      assert_equal 3, @cache.read("foo")
    end
  end

  def test_local_cache_of_decrement
    @cache.with_local_cache do
      @cache.write("foo", 1, raw: true)
      @peek.write("foo", 3, raw: true)
      @cache.decrement("foo")
      assert_equal 2, @cache.read("foo")
    end
  end

  def test_local_cache_of_fetch_multi
    @cache.with_local_cache do
      @cache.fetch_multi("foo", "bar") { |_key| true }
      @peek.delete("foo")
      @peek.delete("bar")
      assert_equal true, @cache.read("foo")
      assert_equal true, @cache.read("bar")
    end
  end

  def test_middleware
    app = lambda { |env|
      result = @cache.write("foo", "bar")
      assert_equal "bar", @cache.read("foo") # make sure 'foo' was written
      assert result
      [200, {}, []]
    }
    app = @cache.middleware.new(app)
    app.call({})
  end
end
