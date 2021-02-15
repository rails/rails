# frozen_string_literal: true

# Tests the base functionality that should be identical across all cache stores.
module CacheStoreBehavior
  def test_should_read_and_write_strings
    assert @cache.write("foo", "bar")
    assert_equal "bar", @cache.read("foo")
  end

  def test_should_overwrite
    @cache.write("foo", "bar")
    @cache.write("foo", "baz")
    assert_equal "baz", @cache.read("foo")
  end

  def test_fetch_without_cache_miss
    @cache.write("foo", "bar")
    assert_not_called(@cache, :write) do
      assert_equal "bar", @cache.fetch("foo") { "baz" }
    end
  end

  def test_fetch_with_cache_miss
    assert_called_with(@cache, :write, ["foo", "baz", @cache.options]) do
      assert_equal "baz", @cache.fetch("foo") { "baz" }
    end
  end

  def test_fetch_with_cache_miss_passes_key_to_block
    cache_miss = false
    assert_equal 3, @cache.fetch("foo") { |key| cache_miss = true; key.length }
    assert cache_miss

    cache_miss = false
    assert_equal 3, @cache.fetch("foo") { |key| cache_miss = true; key.length }
    assert_not cache_miss
  end

  def test_fetch_with_forced_cache_miss
    @cache.write("foo", "bar")
    assert_not_called(@cache, :read) do
      assert_called_with(@cache, :write, ["foo", "bar", @cache.options.merge(force: true)]) do
        @cache.fetch("foo", force: true) { "bar" }
      end
    end
  end

  def test_fetch_with_cached_nil
    @cache.write("foo", nil)
    assert_not_called(@cache, :write) do
      assert_nil @cache.fetch("foo") { "baz" }
    end
  end

  def test_fetch_cache_miss_with_skip_nil
    assert_not_called(@cache, :write) do
      assert_nil @cache.fetch("foo", skip_nil: true) { nil }
      assert_equal false, @cache.exist?("foo")
    end
  end

  def test_fetch_with_forced_cache_miss_with_block
    @cache.write("foo", "bar")
    assert_equal "foo_bar", @cache.fetch("foo", force: true) { "foo_bar" }
  end

  def test_fetch_with_forced_cache_miss_without_block
    @cache.write("foo", "bar")
    assert_raises(ArgumentError) do
      @cache.fetch("foo", force: true)
    end

    assert_equal "bar", @cache.read("foo")
  end

  def test_fetch_with_deferred_update_without_cache_miss
    @cache.write("foo", "bar")
    assert_not_called(@cache, :write) do
      assert_equal "bar", @cache.fetch_with_deferred_update("foo", 5.minutes) { "baz" }
    end
  end

  def test_fetch_with_deferred_update_with_no_cache_entry
    assert_not_called(@cache, :write) do
      cache_miss = false
      assert_nil @cache.fetch_with_deferred_update("foo", 5.minutes) { cache_miss = true }
      assert cache_miss
    end
  end

  def test_fetch_with_deferred_update_with_expired_cache_entry
    time = Time.now
    @cache.write("foo", "bar", expires_in: 10)

    Time.stub(:now, time + 11) do
      assert_called_with(@cache, :write, ["foo", "bar", @cache.options.merge(expires_in: 300)]) do
        cache_miss = false
        assert_equal "bar", @cache.fetch_with_deferred_update("foo", 5.minutes) { cache_miss = true; "baz" }
        assert cache_miss
      end
    end
  end

  def test_fetch_with_deferred_update_with_cache_miss_passes_key_to_block
    time = Time.now
    @cache.write("foo", "bar", expires_in: 10)

    Time.stub(:now, time + 11) do
      key_in_block = nil
      assert_equal "bar", @cache.fetch_with_deferred_update("foo", 5.minutes) { |key| key_in_block = key }
      assert_equal "foo", key_in_block
    end
  end

  def test_should_read_and_write_hash
    assert @cache.write("foo", a: "b")
    assert_equal({ a: "b" }, @cache.read("foo"))
  end

  def test_should_read_and_write_integer
    assert @cache.write("foo", 1)
    assert_equal 1, @cache.read("foo")
  end

  def test_should_read_and_write_nil
    assert @cache.write("foo", nil)
    assert_nil @cache.read("foo")
  end

  def test_should_read_and_write_false
    assert @cache.write("foo", false)
    assert_equal false, @cache.read("foo")
  end

  def test_read_multi
    @cache.write("foo", "bar")
    @cache.write("fu", "baz")
    @cache.write("fud", "biz")
    assert_equal({ "foo" => "bar", "fu" => "baz" }, @cache.read_multi("foo", "fu"))
  end

  def test_read_multi_with_expires
    time = Time.now
    @cache.write("foo", "bar", expires_in: 10)
    @cache.write("fu", "baz")
    @cache.write("fud", "biz")
    Time.stub(:now, time + 11) do
      assert_equal({ "fu" => "baz" }, @cache.read_multi("foo", "fu"))
    end
  end

  def test_read_multi_with_empty_keys_and_a_logger_and_no_namespace
    @cache.options[:namespace] = nil
    @cache.logger = ActiveSupport::Logger.new(nil)
    assert_equal({}, @cache.read_multi)
  end

  def test_fetch_multi
    @cache.write("foo", "bar")
    @cache.write("fud", "biz")

    values = @cache.fetch_multi("foo", "fu", "fud") { |value| value * 2 }

    assert_equal({ "foo" => "bar", "fu" => "fufu", "fud" => "biz" }, values)
    assert_equal("fufu", @cache.read("fu"))
  end

  def test_fetch_multi_without_expires_in
    @cache.write("foo", "bar")
    @cache.write("fud", "biz")

    values = @cache.fetch_multi("foo", "fu", "fud", expires_in: nil) { |value| value * 2 }

    assert_equal({ "foo" => "bar", "fu" => "fufu", "fud" => "biz" }, values)
    assert_equal("fufu", @cache.read("fu"))
  end

  def test_fetch_multi_with_objects
    cache_struct = Struct.new(:cache_key, :title)
    foo = cache_struct.new("foo", "FOO!")
    bar = cache_struct.new("bar")

    @cache.write("bar", "BAM!")

    values = @cache.fetch_multi(foo, bar) { |object| object.title }

    assert_equal({ foo => "FOO!", bar => "BAM!" }, values)
  end

  def test_fetch_multi_returns_ordered_names
    @cache.write("bam", "BAM")

    values = @cache.fetch_multi("foo", "bar", "bam") { |key| key.upcase }

    assert_equal(%w(foo bar bam), values.keys)
  end

  def test_fetch_multi_without_block
    assert_raises(ArgumentError) do
      @cache.fetch_multi("foo")
    end
  end

  # Use strings that are guaranteed to compress well, so we can easily tell if
  # the compression kicked in or not.
  SMALL_STRING = "0" * 100
  LARGE_STRING = "0" * 2.kilobytes

  SMALL_OBJECT = { data: SMALL_STRING }
  LARGE_OBJECT = { data: LARGE_STRING }

  def test_nil_with_default_compression_settings
    assert_uncompressed(nil)
  end

  def test_nil_with_compress_true
    assert_uncompressed(nil, compress: true)
  end

  def test_nil_with_compress_false
    assert_uncompressed(nil, compress: false)
  end

  def test_nil_with_compress_low_compress_threshold
    assert_uncompressed(nil, compress: true, compress_threshold: 1)
  end

  def test_small_string_with_default_compression_settings
    assert_uncompressed(SMALL_STRING)
  end

  def test_small_string_with_compress_true
    assert_uncompressed(SMALL_STRING, compress: true)
  end

  def test_small_string_with_compress_false
    assert_uncompressed(SMALL_STRING, compress: false)
  end

  def test_small_string_with_low_compress_threshold
    assert_compressed(SMALL_STRING, compress: true, compress_threshold: 1)
  end

  def test_small_object_with_default_compression_settings
    assert_uncompressed(SMALL_OBJECT)
  end

  def test_small_object_with_compress_true
    assert_uncompressed(SMALL_OBJECT, compress: true)
  end

  def test_small_object_with_compress_false
    assert_uncompressed(SMALL_OBJECT, compress: false)
  end

  def test_small_object_with_low_compress_threshold
    assert_compressed(SMALL_OBJECT, compress: true, compress_threshold: 1)
  end

  def test_large_string_with_compress_true
    assert_compressed(LARGE_STRING, compress: true)
  end

  def test_large_string_with_compress_false
    assert_uncompressed(LARGE_STRING, compress: false)
  end

  def test_large_string_with_high_compress_threshold
    assert_uncompressed(LARGE_STRING, compress: true, compress_threshold: 1.megabyte)
  end

  def test_large_object_with_compress_true
    assert_compressed(LARGE_OBJECT, compress: true)
  end

  def test_large_object_with_compress_false
    assert_uncompressed(LARGE_OBJECT, compress: false)
  end

  def test_large_object_with_high_compress_threshold
    assert_uncompressed(LARGE_OBJECT, compress: true, compress_threshold: 1.megabyte)
  end

  def test_incompressable_data
    assert_uncompressed(nil, compress: true, compress_threshold: 1)
    assert_uncompressed(true, compress: true, compress_threshold: 1)
    assert_uncompressed(false, compress: true, compress_threshold: 1)
    assert_uncompressed(0, compress: true, compress_threshold: 1)
    assert_uncompressed(1.2345, compress: true, compress_threshold: 1)
    assert_uncompressed("", compress: true, compress_threshold: 1)

    incompressible = nil

    # generate an incompressible string
    loop do
      incompressible = SecureRandom.random_bytes(1.kilobyte)
      break if incompressible.bytesize < Zlib::Deflate.deflate(incompressible).bytesize
    end

    assert_uncompressed(incompressible, compress: true, compress_threshold: 1)
  end

  def test_cache_key
    obj = Object.new
    def obj.cache_key
      :foo
    end
    @cache.write(obj, "bar")
    assert_equal "bar", @cache.read("foo")
  end

  def test_param_as_cache_key
    obj = Object.new
    def obj.to_param
      "foo"
    end
    @cache.write(obj, "bar")
    assert_equal "bar", @cache.read("foo")
  end

  def test_unversioned_cache_key
    obj = Object.new
    def obj.cache_key
      "foo"
    end
    def obj.cache_key_with_version
      "foo-v1"
    end
    @cache.write(obj, "bar")
    assert_equal "bar", @cache.read("foo")
  end

  def test_array_as_cache_key
    @cache.write([:fu, "foo"], "bar")
    assert_equal "bar", @cache.read("fu/foo")
  end

  InstanceTest = Struct.new(:name, :id) do
    def cache_key
      "#{name}/#{id}"
    end

    def to_param
      "hello"
    end
  end

  def test_array_with_single_instance_as_cache_key_uses_cache_key_method
    test_instance_one = InstanceTest.new("test", 1)
    test_instance_two = InstanceTest.new("test", 2)

    @cache.write([test_instance_one], "one")
    @cache.write([test_instance_two], "two")

    assert_equal "one", @cache.read([test_instance_one])
    assert_equal "two", @cache.read([test_instance_two])
  end

  def test_array_with_multiple_instances_as_cache_key_uses_cache_key_method
    test_instance_one = InstanceTest.new("test", 1)
    test_instance_two = InstanceTest.new("test", 2)
    test_instance_three = InstanceTest.new("test", 3)

    @cache.write([test_instance_one, test_instance_three], "one")
    @cache.write([test_instance_two, test_instance_three], "two")

    assert_equal "one", @cache.read([test_instance_one, test_instance_three])
    assert_equal "two", @cache.read([test_instance_two, test_instance_three])
  end

  def test_format_of_expanded_key_for_single_instance
    test_instance_one = InstanceTest.new("test", 1)

    expanded_key = @cache.send(:expanded_key, test_instance_one)

    assert_equal expanded_key, test_instance_one.cache_key
  end

  def test_format_of_expanded_key_for_single_instance_in_array
    test_instance_one = InstanceTest.new("test", 1)

    expanded_key = @cache.send(:expanded_key, [test_instance_one])

    assert_equal expanded_key, test_instance_one.cache_key
  end

  def test_hash_as_cache_key
    @cache.write({ foo: 1, fu: 2 }, "bar")
    assert_equal "bar", @cache.read("foo=1/fu=2")
  end

  def test_keys_are_case_sensitive
    @cache.write("foo", "bar")
    assert_nil @cache.read("FOO")
  end

  def test_exist
    @cache.write("foo", "bar")
    assert_equal true, @cache.exist?("foo")
    assert_equal false, @cache.exist?("bar")
  end

  def test_nil_exist
    @cache.write("foo", nil)
    assert @cache.exist?("foo")
  end

  def test_delete
    @cache.write("foo", "bar")
    assert @cache.exist?("foo")
    assert @cache.delete("foo")
    assert_not @cache.exist?("foo")
  end

  def test_delete_multi
    @cache.write("foo", "bar")
    assert @cache.exist?("foo")
    @cache.write("hello", "world")
    assert @cache.exist?("hello")
    assert_equal 2, @cache.delete_multi(["foo", "does_not_exist", "hello"])
    assert_not @cache.exist?("foo")
    assert_not @cache.exist?("hello")
  end

  def test_original_store_objects_should_not_be_immutable
    bar = +"bar"
    @cache.write("foo", bar)
    assert_nothing_raised { bar.gsub!(/.*/, "baz") }
  end

  def test_expires_in
    time = Time.local(2008, 4, 24)

    Time.stub(:now, time) do
      @cache.write("foo", "bar")
      assert_equal "bar", @cache.read("foo")
    end

    Time.stub(:now, time + 30) do
      assert_equal "bar", @cache.read("foo")
    end

    Time.stub(:now, time + 61) do
      assert_nil @cache.read("foo")
    end
  end

  def test_expire_in_is_alias_for_expires_in
    time = Time.local(2008, 4, 24)

    Time.stub(:now, time) do
      @cache.write("foo", "bar", expire_in: 20)
      assert_equal "bar", @cache.read("foo")
    end

    Time.stub(:now, time + 10) do
      assert_equal "bar", @cache.read("foo")
    end

    Time.stub(:now, time + 21) do
      assert_nil @cache.read("foo")
    end
  end

  def test_expired_in_is_alias_for_expires_in
    time = Time.local(2008, 4, 24)

    Time.stub(:now, time) do
      @cache.write("foo", "bar", expired_in: 20)
      assert_equal "bar", @cache.read("foo")
    end

    Time.stub(:now, time + 10) do
      assert_equal "bar", @cache.read("foo")
    end

    Time.stub(:now, time + 21) do
      assert_nil @cache.read("foo")
    end
  end

  def test_race_condition_protection_skipped_if_not_defined
    @cache.write("foo", "bar")
    time = @cache.send(:read_entry, @cache.send(:normalize_key, "foo", {}), **{}).expires_at

    Time.stub(:now, Time.at(time)) do
      result = @cache.fetch("foo") do
        assert_nil @cache.read("foo")
        "baz"
      end
      assert_equal "baz", result
    end
  end

  def test_race_condition_protection_is_limited
    time = Time.now
    @cache.write("foo", "bar", expires_in: 60)
    Time.stub(:now, time + 71) do
      result = @cache.fetch("foo", race_condition_ttl: 10) do
        assert_nil @cache.read("foo")
        "baz"
      end
      assert_equal "baz", result
    end
  end

  def test_race_condition_protection_is_safe
    time = Time.now
    @cache.write("foo", "bar", expires_in: 60)
    Time.stub(:now, time + 61) do
      begin
        @cache.fetch("foo", race_condition_ttl: 10) do
          assert_equal "bar", @cache.read("foo")
          raise ArgumentError.new
        end
      rescue ArgumentError
      end
      assert_equal "bar", @cache.read("foo")
    end
    Time.stub(:now, time + 91) do
      assert_nil @cache.read("foo")
    end
  end

  def test_race_condition_protection
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

  def test_crazy_key_characters
    crazy_key = "#/:*(<+=> )&$%@?;'\"\'`~-"
    assert @cache.write(crazy_key, "1", raw: true)
    assert_equal "1", @cache.read(crazy_key, raw: true)
    assert_equal "1", @cache.fetch(crazy_key, raw: true)
    assert @cache.delete(crazy_key)
    assert_equal "2", @cache.fetch(crazy_key, raw: true) { "2" }
    assert_equal 3, @cache.increment(crazy_key)
    assert_equal 2, @cache.decrement(crazy_key)
  end

  def test_really_long_keys
    key = "x" * 2048
    assert @cache.write(key, "bar")
    assert_equal "bar", @cache.read(key)
    assert_equal "bar", @cache.fetch(key)
    assert_nil @cache.read("#{key}x")
    assert_equal({ key => "bar" }, @cache.read_multi(key))
    assert @cache.delete(key)
  end

  def test_cache_hit_instrumentation
    key = "test_key"
    @events = []
    ActiveSupport::Notifications.subscribe "cache_read.active_support" do |*args|
      @events << ActiveSupport::Notifications::Event.new(*args)
    end
    assert @cache.write(key, "1", raw: true)
    assert @cache.fetch(key, raw: true) { }
    assert_equal 1, @events.length
    assert_equal "cache_read.active_support", @events[0].name
    assert_equal :fetch, @events[0].payload[:super_operation]
    assert @events[0].payload[:hit]
  ensure
    ActiveSupport::Notifications.unsubscribe "cache_read.active_support"
  end

  def test_cache_miss_instrumentation
    @events = []
    ActiveSupport::Notifications.subscribe(/^cache_(.*)\.active_support$/) do |*args|
      @events << ActiveSupport::Notifications::Event.new(*args)
    end
    assert_not @cache.fetch("bad_key") { }
    assert_equal 3, @events.length
    assert_equal "cache_read.active_support", @events[0].name
    assert_equal "cache_generate.active_support", @events[1].name
    assert_equal "cache_write.active_support", @events[2].name
    assert_equal :fetch, @events[0].payload[:super_operation]
    assert_not @events[0].payload[:hit]
  ensure
    ActiveSupport::Notifications.unsubscribe "cache_read.active_support"
  end

  private
    def assert_compressed(value, **options)
      assert_compression(true, value, **options)
    end

    def assert_uncompressed(value, **options)
      assert_compression(false, value, **options)
    end

    def assert_compression(should_compress, value, **options)
      freeze_time do
        @cache.write("actual", value, options)
        @cache.write("uncompressed", value, options.merge(compress: false))
      end

      if value.nil?
        assert_nil @cache.read("actual")
        assert_nil @cache.read("uncompressed")
      else
        assert_equal value, @cache.read("actual")
        assert_equal value, @cache.read("uncompressed")
      end

      actual_entry = @cache.send(:read_entry, @cache.send(:normalize_key, "actual", {}), **{})
      uncompressed_entry = @cache.send(:read_entry, @cache.send(:normalize_key, "uncompressed", {}), **{})

      actual_size = Marshal.dump(actual_entry).bytesize
      uncompressed_size = Marshal.dump(uncompressed_entry).bytesize

      if should_compress
        assert_operator actual_size, :<, uncompressed_size, "value should be compressed"
      else
        assert_equal uncompressed_size, actual_size, "value should not be compressed"
      end
    end
end
