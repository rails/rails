# frozen_string_literal: true

module LocalCacheBehavior
  def test_instrumentation_with_local_cache
    events = with_instrumentation "write" do
      @cache.write("foo", "bar")
    end
    assert_equal @cache.class.name, events[0].payload[:store]

    @cache.with_local_cache do
      events = with_instrumentation "read" do
        @cache.read("foo")
        @cache.read("foo")
      end

      expected = [@cache.class.name, @cache.send(:local_cache).class.name]
      assert_equal expected, events.map { |p| p.payload[:store] }
    end
  end

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

  def test_local_cache_of_read_returns_a_copy_of_the_entry
    @cache.with_local_cache do
      @cache.write(:foo, type: "bar")
      value = @cache.read(:foo)
      assert_equal("bar", value.delete(:type))
      assert_equal({ type: "bar" }, @cache.read(:foo))
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
      @cache.send(:local_cache).write_entry "foo", "bar"
      assert_equal "bar", @cache.send(:local_cache).fetch_entry("foo")
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

  def test_local_cache_of_delete_matched
    begin
      @cache.delete_matched("*")
    rescue NotImplementedError
      skip
    end

    @cache.with_local_cache do
      @cache.write("foo", "bar")
      @cache.write("fop", "bar")
      @cache.write("bar", "foo")
      @cache.delete_matched("fo*")
      assert_not @cache.exist?("foo")
      assert_not @cache.exist?("fop")
      assert_equal "foo", @cache.read("bar")
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

      expected = @peek.read("foo", raw: true)
      assert_equal 3, Integer(expected)
      assert_equal expected, @cache.read("foo", raw: true)
    end
  end

  def test_local_cache_of_decrement
    @cache.with_local_cache do
      @cache.write("foo", 1, raw: true)
      @peek.write("foo", 3, raw: true)

      @cache.decrement("foo")
      expected = @peek.read("foo", raw: true)
      assert_equal 2, Integer(expected)
      assert_equal expected, @cache.read("foo", raw: true)
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

  def test_local_cache_of_read_multi
    @cache.with_local_cache do
      @cache.write("foo", "foo", raw: true)
      @cache.write("bar", "bar", raw: true)
      values = @cache.read_multi("foo", "bar", raw: true)
      assert_equal "foo", @cache.read("foo", raw: true)
      assert_equal "bar", @cache.read("bar", raw: true)
      assert_equal "foo", values["foo"]
      assert_equal "bar", values["bar"]
    end
  end

  def test_initial_object_mutation_after_write
    @cache.with_local_cache do
      initial = +"bar"
      @cache.write("foo", initial)
      initial << "baz"
      assert_equal "bar", @cache.read("foo")
    end
  end

  def test_initial_object_mutation_after_fetch
    @cache.with_local_cache do
      initial = +"bar"
      @cache.fetch("foo") { initial }
      initial << "baz"
      assert_equal "bar", @cache.read("foo")
      assert_equal "bar", @cache.fetch("foo")
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

  def test_local_race_condition_protection
    @cache.with_local_cache do
      time = Time.now
      @cache.write("foo", "bar", expires_in: 60)
      Time.stub(:now, time + 61) do
        result = @cache.fetch("foo", race_condition_ttl: 10) do
          assert_equal "bar", @cache.read("foo")
          "baz"
        end
        assert_equal "baz", result
      end
    end
  end

  def test_local_cache_should_read_and_write_false
    @cache.with_local_cache do
      assert @cache.write("foo", false)
      assert_equal false, @cache.read("foo")
    end
  end
end
