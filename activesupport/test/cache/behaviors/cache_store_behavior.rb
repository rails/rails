# frozen_string_literal: true

require "active_support/core_ext/numeric/time"
require "active_support/error_reporter/test_helper"

# Tests the base functionality that should be identical across all cache stores.
module CacheStoreBehavior
  def test_should_read_and_write_strings
    key = SecureRandom.uuid
    assert_equal true, @cache.write(key, "bar")
    assert_equal "bar", @cache.read(key)
  end

  def test_should_overwrite
    key = SecureRandom.uuid
    assert_equal true, @cache.write(key, "bar")
    assert_equal true, @cache.write(key, "baz")
    assert_equal "baz", @cache.read(key)
  end

  def test_fetch_without_cache_miss
    key = SecureRandom.uuid
    @cache.write(key, "bar")
    assert_not_called(@cache, :write) do
      assert_equal "bar", @cache.fetch(key) { "baz" }
    end
  end

  def test_fetch_with_cache_miss
    key = SecureRandom.uuid
    assert_called_with(@cache, :write, [key, "baz", @cache.options]) do
      assert_equal "baz", @cache.fetch(key) { "baz" }
    end
  end

  def test_fetch_with_cache_miss_passes_key_to_block
    cache_miss = false
    key = SecureRandom.alphanumeric(10)
    assert_equal 10, @cache.fetch(key) { |key| cache_miss = true; key.length }
    assert cache_miss

    cache_miss = false
    assert_equal 10, @cache.fetch(key) { |fetch_key| cache_miss = true; fetch_key.length }
    assert_not cache_miss
  end

  def test_fetch_with_dynamic_options
    key = SecureRandom.uuid
    expiry = 10.minutes.from_now
    expected_options = @cache.options.dup
    expected_options.delete(:expires_in)
    expected_options.merge!(
      expires_at: expiry,
      version: "v42",
    )

    assert_called_with(@cache, :write, [key, "bar", expected_options]) do
      @cache.fetch(key) do |key, options|
        assert_equal @cache.options[:expires_in], options.expires_in
        assert_nil options.expires_at
        assert_nil options.version

        options.expires_at = expiry
        options.version = "v42"

        assert_nil options.expires_in
        assert_equal expiry, options.expires_at
        assert_equal "v42", options.version

        "bar"
      end
    end
  end

  def test_fetch_with_forced_cache_miss
    key = SecureRandom.uuid
    @cache.write(key, "bar")
    assert_not_called(@cache, :read) do
      assert_called_with(@cache, :write, [key, "bar", @cache.options.merge(force: true)]) do
        @cache.fetch(key, force: true) { "bar" }
      end
    end
  end

  def test_fetch_with_cached_nil
    key = SecureRandom.uuid
    @cache.write(key, nil)
    assert_not_called(@cache, :write) do
      assert_nil @cache.fetch(key) { "baz" }
    end
  end

  def test_fetch_cache_miss_with_skip_nil
    key = SecureRandom.uuid
    assert_not_called(@cache, :write) do
      assert_nil @cache.fetch(key, skip_nil: true) { nil }
      assert_equal false, @cache.exist?("foo")
    end
  end

  def test_fetch_with_forced_cache_miss_with_block
    key = SecureRandom.uuid
    @cache.write(key, "bar")
    assert_equal "foo_bar", @cache.fetch(key, force: true) { "foo_bar" }
  end

  def test_fetch_with_forced_cache_miss_without_block
    key = SecureRandom.uuid
    @cache.write(key, "bar")
    assert_raises(ArgumentError) do
      @cache.fetch(key, force: true)
    end

    assert_equal "bar", @cache.read(key)
  end

  def test_should_read_and_write_hash
    key = SecureRandom.uuid
    assert_equal true, @cache.write(key, a: "b")
    assert_equal({ a: "b" }, @cache.read(key))
  end

  def test_should_read_and_write_integer
    key = SecureRandom.uuid
    assert_equal true, @cache.write(key, 1)
    assert_equal 1, @cache.read(key)
  end

  def test_should_read_and_write_nil
    key = SecureRandom.uuid
    assert_equal true, @cache.write(key, nil)
    assert_nil @cache.read(key)
  end

  def test_should_read_and_write_false
    key = SecureRandom.uuid
    assert_equal true, @cache.write(key, false)
    assert_equal false, @cache.read(key)
  end

  def test_read_multi
    key = SecureRandom.uuid
    @cache.write(key, "bar")
    other_key = SecureRandom.uuid
    @cache.write(other_key, "baz")
    @cache.write(SecureRandom.alphanumeric, "biz")
    assert_equal({ key => "bar", other_key => "baz" }, @cache.read_multi(key, other_key))
  end

  def test_read_multi_empty_list
    assert_equal({}, @cache.read_multi())
  end

  def test_read_multi_with_expires
    time = Time.now
    key = SecureRandom.uuid
    other_key = SecureRandom.uuid
    @cache.write(key, "bar", expires_in: 10)
    @cache.write(other_key, "baz")
    @cache.write(SecureRandom.alphanumeric, "biz")
    Time.stub(:now, time + 11) do
      assert_equal({ other_key => "baz" }, @cache.read_multi(other_key, SecureRandom.alphanumeric))
    end
  end

  def test_write_multi
    key = SecureRandom.uuid
    @cache.write_multi("#{key}1" => 1, "#{key}2" => 2)
    assert_equal 1, @cache.read("#{key}1")
    assert_equal 2, @cache.read("#{key}2")
  end

  def test_write_multi_empty_hash
    assert @cache.write_multi({})
  end

  def test_write_multi_expires_in
    key = SecureRandom.uuid
    @cache.write_multi({ key => 1 }, expires_in: 10)

    travel(11.seconds) do
      assert_nil @cache.read(key)
    end
  end

  def test_fetch_multi
    key = SecureRandom.uuid
    other_key = SecureRandom.uuid
    third_key = SecureRandom.alphanumeric
    @cache.write(key, "bar")
    @cache.write(other_key, "biz")

    values = @cache.fetch_multi(key, other_key, third_key) { |value| value * 2 }

    assert_equal({ key => "bar", other_key => "biz", third_key => (third_key * 2) }, values)
    assert_equal((third_key * 2), @cache.read(third_key))
  end

  def test_fetch_multi_empty_hash
    assert_equal({}, @cache.fetch_multi() { raise "Not called" })
  end

  def test_fetch_multi_without_expires_in
    key = SecureRandom.uuid
    other_key = SecureRandom.uuid
    third_key = SecureRandom.alphanumeric
    @cache.write(key, "bar")
    @cache.write(other_key, "biz")

    values = @cache.fetch_multi(key, third_key, other_key, expires_in: nil) { |value| value * 2 }

    assert_equal({ key => "bar", third_key => (third_key * 2), other_key => "biz" }, values)
    assert_equal((third_key * 2), @cache.read(third_key))
  end

  def test_fetch_multi_with_objects
    key = SecureRandom.uuid
    other_key = SecureRandom.uuid
    cache_struct = Struct.new(:cache_key, :title)
    foo = cache_struct.new(key, "FOO!")
    bar = cache_struct.new(other_key)

    @cache.write(other_key, "BAM!")

    values = @cache.fetch_multi(foo, bar) { |object| object.title }

    assert_equal({ foo => "FOO!", bar => "BAM!" }, values)
  end

  def test_fetch_multi_returns_ordered_names
    key = SecureRandom.alphanumeric.downcase
    other_key = SecureRandom.alphanumeric.downcase
    third_key = SecureRandom.alphanumeric.downcase
    @cache.write(key, "BAM")

    values = @cache.fetch_multi(other_key, third_key, key) { |key| key.upcase }

    assert_equal([other_key, third_key, key], values.keys)
    assert_equal([other_key.upcase, third_key.upcase, "BAM"], values.values)
  end

  def test_fetch_multi_without_block
    assert_raises(ArgumentError) do
      @cache.fetch_multi(SecureRandom.alphanumeric)
    end
  end

  def test_fetch_multi_with_forced_cache_miss
    key = SecureRandom.uuid
    other_key = SecureRandom.uuid
    @cache.write(key, "bar")

    values = @cache.fetch_multi(key, other_key, force: true) { |value| value * 2 }

    assert_equal({ key => (key * 2), other_key => (other_key * 2) }, values)
    assert_equal(key * 2, @cache.read(key))
    assert_equal(other_key * 2, @cache.read(other_key))
  end

  def test_fetch_multi_with_skip_nil
    key = SecureRandom.uuid
    other_key = SecureRandom.uuid

    values = @cache.fetch_multi(key, other_key, skip_nil: true) { |k| k == key ? k : nil }

    assert_equal({ key => key, other_key => nil }, values)
    assert_equal(false, @cache.exist?(other_key))
  end

  def test_fetch_multi_uses_write_multi_entries_store_provider_interface
    assert_called(@cache, :write_multi_entries) do
      @cache.fetch_multi "a", "b", "c" do |key|
        key * 2
      end
    end
  end

  def test_cache_key
    key = SecureRandom.uuid
    klass = Class.new do
      def initialize(key)
        @key = key
      end
      def cache_key
        @key
      end
    end
    @cache.write(klass.new(key), "bar")
    assert_equal "bar", @cache.read(key)
  end

  def test_param_as_cache_key
    key = SecureRandom.uuid
    klass = Class.new do
      def initialize(key)
        @key = key
      end
      def to_param
        @key
      end
    end
    @cache.write(klass.new(key), "bar")
    assert_equal "bar", @cache.read(key)
  end

  def test_unversioned_cache_key
    key = SecureRandom.uuid
    klass = Class.new do
      def initialize(key)
        @key = key
      end
      def cache_key
        @key
      end
      def cache_key_with_version
        "#{@key}-v1"
      end
    end
    @cache.write(klass.new(key), "bar")
    assert_equal "bar", @cache.read(key)
  end

  def test_array_as_cache_key
    key = SecureRandom.uuid
    @cache.write([key, "foo"], "bar")
    assert_equal "bar", @cache.read("#{key}/foo")
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
    key = SecureRandom.alphanumeric
    other_key = SecureRandom.alphanumeric
    test_instance_one = InstanceTest.new(key, 1)
    test_instance_two = InstanceTest.new(other_key, 2)

    @cache.write([test_instance_one], "one")
    @cache.write([test_instance_two], "two")

    assert_equal "one", @cache.read([test_instance_one])
    assert_equal "two", @cache.read([test_instance_two])
  end

  def test_array_with_multiple_instances_as_cache_key_uses_cache_key_method
    key = SecureRandom.alphanumeric
    other_key = SecureRandom.alphanumeric
    third_key = SecureRandom.alphanumeric
    test_instance_one = InstanceTest.new(key, 1)
    test_instance_two = InstanceTest.new(other_key, 2)
    test_instance_three = InstanceTest.new(third_key, 3)

    @cache.write([test_instance_one, test_instance_three], "one")
    @cache.write([test_instance_two, test_instance_three], "two")

    assert_equal "one", @cache.read([test_instance_one, test_instance_three])
    assert_equal "two", @cache.read([test_instance_two, test_instance_three])
  end

  def test_format_of_expanded_key_for_single_instance
    key = SecureRandom.alphanumeric
    test_instance_one = InstanceTest.new(key, 1)

    expanded_key = @cache.send(:expanded_key, test_instance_one)

    assert_equal expanded_key, test_instance_one.cache_key
  end

  def test_format_of_expanded_key_for_single_instance_in_array
    key = SecureRandom.alphanumeric
    test_instance_one = InstanceTest.new(key, 1)

    expanded_key = @cache.send(:expanded_key, [test_instance_one])

    assert_equal expanded_key, test_instance_one.cache_key
  end

  def test_hash_as_cache_key
    key = SecureRandom.alphanumeric
    other_key = SecureRandom.alphanumeric
    @cache.write({ key => 1, other_key => 2 }, "bar")
    assert_equal "bar", @cache.read({ key => 1, other_key => 2 })
  end

  def test_keys_are_case_sensitive
    key = "case_sensitive_key"
    @cache.write(key, "bar")
    assert_nil @cache.read(key.upcase)
  end

  def test_blank_key
    invalid_keys = [nil, "", [], {}]
    invalid_keys.each do |key|
      assert_raises(ArgumentError) { @cache.write(key, "bar") }
      assert_raises(ArgumentError) { @cache.read(key) }
      assert_raises(ArgumentError) { @cache.delete(key) }
    end

    valid_keys = ["foo", ["bar"], { foo: "bar" }, 0, 1, InstanceTest.new("foo", 2)]
    valid_keys.each do |key|
      assert_nothing_raised { @cache.write(key, "bar") }
      assert_nothing_raised { @cache.read(key) }
      assert_nothing_raised { @cache.delete(key) }
    end
  end

  def test_exist
    key = SecureRandom.alphanumeric
    @cache.write(key, "bar")
    assert_equal true, @cache.exist?(key)
    assert_equal false, @cache.exist?(SecureRandom.uuid)
  end

  def test_nil_exist
    key = SecureRandom.alphanumeric
    @cache.write(key, nil)
    assert @cache.exist?(key)
  end

  def test_delete
    key = SecureRandom.alphanumeric
    @cache.write(key, "bar")
    assert @cache.exist?(key)
    assert_same true, @cache.delete(key)
    assert_not @cache.exist?(key)
  end

  def test_delete_returns_false_if_not_exist
    key = SecureRandom.alphanumeric
    assert_same false, @cache.delete(key)
  end

  def test_delete_multi
    key = SecureRandom.alphanumeric
    @cache.write(key, "bar")
    assert @cache.exist?(key)
    other_key = SecureRandom.alphanumeric
    @cache.write(other_key, "world")
    assert @cache.exist?(other_key)
    assert_equal 2, @cache.delete_multi([key, SecureRandom.uuid, other_key])
    assert_not @cache.exist?(key)
    assert_not @cache.exist?(other_key)
  end

  def test_delete_multi_empty_list
    assert_equal(0, @cache.delete_multi([]))
  end

  def test_original_store_objects_should_not_be_immutable
    bar = +"bar"
    key = SecureRandom.alphanumeric
    @cache.write(key, bar)
    assert_nothing_raised { bar.gsub!(/.*/, "baz") }
  end

  def test_expires_in
    time = Time.local(2008, 4, 24)

    key = SecureRandom.alphanumeric
    other_key = SecureRandom.alphanumeric

    Time.stub(:now, time) do
      @cache.write(key, "bar", expires_in: 1.minute)
      @cache.write(other_key, "spam", expires_in: 2.minute)
      assert_equal "bar", @cache.read(key)
      assert_equal "spam", @cache.read(other_key)
    end

    Time.stub(:now, time + 30) do
      assert_equal "bar", @cache.read(key)
      assert_equal "spam", @cache.read(other_key)
    end

    Time.stub(:now, time + 1.minute + 1.second) do
      assert_nil @cache.read(key)
      assert_equal "spam", @cache.read(other_key)
    end

    Time.stub(:now, time + 2.minute + 1.second) do
      assert_nil @cache.read(key)
      assert_nil @cache.read(other_key)
    end
  end

  def test_expires_at
    time = Time.local(2008, 4, 24)

    key = SecureRandom.alphanumeric
    Time.stub(:now, time) do
      @cache.write(key, "bar", expires_at: time + 15.seconds)
      assert_equal "bar", @cache.read(key)
    end

    Time.stub(:now, time + 10) do
      assert_equal "bar", @cache.read(key)
    end

    Time.stub(:now, time + 30) do
      assert_nil @cache.read(key)
    end
  end

  def test_expire_in_is_alias_for_expires_in
    time = Time.local(2008, 4, 24)

    key = SecureRandom.alphanumeric
    Time.stub(:now, time) do
      @cache.write(key, "bar", expire_in: 20)
      assert_equal "bar", @cache.read(key)
    end

    Time.stub(:now, time + 10) do
      assert_equal "bar", @cache.read(key)
    end

    Time.stub(:now, time + 21) do
      assert_nil @cache.read(key)
    end
  end

  def test_expired_in_is_alias_for_expires_in
    time = Time.local(2008, 4, 24)

    key = SecureRandom.alphanumeric
    Time.stub(:now, time) do
      @cache.write(key, "bar", expired_in: 20)
      assert_equal "bar", @cache.read(key)
    end

    Time.stub(:now, time + 10) do
      assert_equal "bar", @cache.read(key)
    end

    Time.stub(:now, time + 21) do
      assert_nil @cache.read(key)
    end
  end

  def test_expires_in_and_expires_at
    key = SecureRandom.uuid
    error = assert_raises(ArgumentError) do
      @cache.write(key, "bar", expire_in: 60, expires_at: 1.minute.from_now)
    end
    assert_equal "Either :expires_in or :expires_at can be supplied, but not both", error.message
  end

  def test_invalid_expiration_time_raises_an_error_when_raise_on_invalid_cache_expiration_time_is_true
    with_raise_on_invalid_cache_expiration_time(true) do
      key = SecureRandom.uuid
      error = assert_raises(ArgumentError) do
        @cache.write(key, "bar", expires_in: -60)
      end
      assert_equal "Cache expiration time is invalid, cannot be negative: -60", error.message
      assert_nil @cache.read(key)
    end
  end

  def test_invalid_expiration_time_reports_and_logs_when_raise_on_invalid_cache_expiration_time_is_false
    with_raise_on_invalid_cache_expiration_time(false) do
      error_message = "Cache expiration time is invalid, cannot be negative: -60"
      report = assert_error_reported(ArgumentError) do
        logs = capture_logs do
          key = SecureRandom.uuid
          @cache.write(key, "bar", expires_in: -60)
          assert_equal "bar", @cache.read(key)
        end
        assert_includes logs, "ArgumentError: #{error_message}"
      end
      assert_includes report.error.message, error_message
    end
  end

  def test_expires_in_from_now_raises_an_error
    time = 1.minute.from_now

    key = SecureRandom.uuid
    error = assert_raises(ArgumentError) do
      @cache.write(key, "bar", expires_in: time)
    end
    assert_equal "expires_in parameter should not be a Time. Did you mean to use expires_at? Got: #{time}", error.message
    assert_nil @cache.read(key)
  end

  def test_race_condition_protection_skipped_if_not_defined
    key = SecureRandom.alphanumeric
    @cache.write(key, "bar")
    time = @cache.send(:read_entry, @cache.send(:normalize_key, key, {}), **{}).expires_at

    Time.stub(:now, Time.at(time)) do
      result = @cache.fetch(key) do
        assert_nil @cache.read(key)
        "baz"
      end
      assert_equal "baz", result
    end
  end

  def test_race_condition_protection_is_limited
    time = Time.now
    key = SecureRandom.uuid
    @cache.write(key, "bar", expires_in: 60)
    Time.stub(:now, time + 71) do
      result = @cache.fetch(key, race_condition_ttl: 10) do
        assert_nil @cache.read(key)
        "baz"
      end
      assert_equal "baz", result
    end
  end

  def test_race_condition_protection_is_safe
    time = Time.now
    key = SecureRandom.uuid
    @cache.write(key, "bar", expires_in: 60)
    Time.stub(:now, time + 61) do
      begin
        @cache.fetch(key, race_condition_ttl: 10) do
          assert_equal "bar", @cache.read(key)
          raise ArgumentError.new
        end
      rescue ArgumentError
      end
      assert_equal "bar", @cache.read(key)
    end
    Time.stub(:now, time + 91) do
      assert_nil @cache.read(key)
    end
  end

  def test_race_condition_protection
    time = Time.now
    key = SecureRandom.uuid
    @cache.write(key, "bar", expires_in: 60)
    Time.stub(:now, time + 61) do
      result = @cache.fetch(key, race_condition_ttl: 10) do
        assert_equal "bar", @cache.read(key)
        "baz"
      end
      assert_equal "baz", result
    end
  end

  def test_fetch_race_condition_protection
    time = Time.now
    key = SecureRandom.uuid
    value = SecureRandom.uuid
    expires_in = 60

    @cache.write(key, value, expires_in:)
    Time.stub(:now, time + expires_in + 1) do
      fetched_value = @cache.fetch(key, expires_in:, race_condition_ttl: 10) do
        SecureRandom.uuid
      end
      assert_not_equal fetched_value, value
      assert_not_nil fetched_value
    end

    Time.stub(:now, time + 2 * expires_in) do
      assert_not_nil @cache.read(key)
    end
  end

  def test_fetch_multi_race_condition_protection
    time = Time.now
    key = SecureRandom.uuid
    other_key = SecureRandom.uuid
    @cache.write(key, "foo", expires_in: 60)
    @cache.write(other_key, "bar", expires_in: 100)
    Time.stub(:now, time + 71) do
      result = @cache.fetch_multi(key, other_key, race_condition_ttl: 10) do
        assert_nil @cache.read(key)
        assert_equal "bar", @cache.read(other_key)
        "baz"
      end
      assert_equal({ key => "baz", other_key => "bar" }, result)
    end
  end

  def test_absurd_key_characters
    absurd_key = "#/:*(<+=> )&$%@?;'\"\'`~-"
    assert @cache.write(absurd_key, "1", raw: true)
    assert_equal "1", @cache.read(absurd_key, raw: true)
    assert_equal "1", @cache.fetch(absurd_key, raw: true)
    assert @cache.delete(absurd_key)
    assert_equal "2", @cache.fetch(absurd_key, raw: true) { "2" }
    assert_equal 3, @cache.increment(absurd_key)
    assert_equal 2, @cache.decrement(absurd_key)
  end

  def test_really_long_keys
    key = SecureRandom.alphanumeric * 2048
    assert @cache.write(key, "bar")
    assert_equal "bar", @cache.read(key)
    assert_equal "bar", @cache.fetch(key)
    assert_nil @cache.read("#{key}x")
    assert_equal({ key => "bar" }, @cache.read_multi(key))
  end

  def test_cache_hit_instrumentation
    key = "test_key"
    @events = []
    ActiveSupport::Notifications.subscribe("cache_read.active_support") { |event| @events << event }
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
    ActiveSupport::Notifications.subscribe(/^cache_(.*)\.active_support$/) { |event| @events << event }
    assert_not @cache.fetch(SecureRandom.uuid) { }
    assert_equal 3, @events.length
    assert_equal "cache_read.active_support", @events[0].name
    assert_equal "cache_generate.active_support", @events[1].name
    assert_equal "cache_write.active_support", @events[2].name
    assert_equal :fetch, @events[0].payload[:super_operation]
    assert_not @events[0].payload[:hit]
  ensure
    ActiveSupport::Notifications.unsubscribe "cache_read.active_support"
  end

  def test_setting_options_in_fetch_block_does_not_change_cache_options
    key = SecureRandom.uuid

    assert_no_changes -> { @cache.options.dup } do
      @cache.fetch(key) do |_key, options|
        options.expires_in = 5.minutes
        "bar"
      end
    end
  end

  private
    def with_raise_on_invalid_cache_expiration_time(new_value, &block)
      old_value = ActiveSupport::Cache::Store.raise_on_invalid_cache_expiration_time
      ActiveSupport::Cache::Store.raise_on_invalid_cache_expiration_time = new_value

      yield
    ensure
      ActiveSupport::Cache::Store.raise_on_invalid_cache_expiration_time = old_value
    end

    def capture_logs(&block)
      old_logger = ActiveSupport::Cache::Store.logger
      log = StringIO.new
      ActiveSupport::Cache::Store.logger = ActiveSupport::Logger.new(log)
      begin
        yield
        log.string
      ensure
        ActiveSupport::Cache::Store.logger = old_logger
      end
    end
end
