# frozen_string_literal: true

require_relative "../../abstract_unit"
require "active_support/cache"
require_relative "../behaviors"
require "dalli"

class MemCacheStoreTest < ActiveSupport::TestCase
  # Emulates a latency on Dalli's back-end for the key latency to facilitate
  # connection pool testing.
  class SlowDalliClient < Dalli::Client
    def get(key, options = {})
      if /latency/.match?(key)
        sleep 3
        super
      else
        super
      end
    end
  end

  class UnavailableDalliServer < Dalli::Protocol::Binary
    def alive? # before https://github.com/petergoldstein/dalli/pull/863
      false
    end

    def ensure_connected! # after https://github.com/petergoldstein/dalli/pull/863
      false
    end
  end

  if ENV["BUILDKITE"]
    MEMCACHE_UP = true
  else
    begin
      servers = ENV["MEMCACHE_SERVERS"] || "localhost:11211"
      ss = Dalli::Client.new(servers).stats
      raise Dalli::DalliError unless ss[servers] || ss[servers + ":11211"]

      MEMCACHE_UP = true
    rescue Dalli::DalliError
      $stderr.puts "Skipping memcached tests. Start memcached and try again."
      MEMCACHE_UP = false
    end
  end

  def lookup_store(*addresses, **options)
    cache = ActiveSupport::Cache.lookup_store(:mem_cache_store, *addresses, { namespace: @namespace, pool: false, socket_timeout: 60 }.merge(options))
    (@_stores ||= []) << cache
    cache
  end

  parallelize(workers: 1)

  def setup
    skip "memcache server is not up" unless MEMCACHE_UP

    @namespace = "test-#{Random.rand(16**32).to_s(16)}"
    @cache = lookup_store(expires_in: 60)
    @peek = lookup_store
    @cache.logger = ActiveSupport::Logger.new(File::NULL)
  end

  def teardown
    @cache.clear
  end

  def after_teardown
    return unless defined?(@_stores) # because skipped test

    stores, @_stores = @_stores, []
    stores.each do |store|
      # Eagerly closing Dalli connection avoid file descriptor exhaustion.
      # Otherwise the test suite is flaky when ran repeatedly
      store.instance_variable_get(:@data).close
    end
  end

  include CacheStoreBehavior
  include CacheStoreVersionBehavior
  include CacheStoreCoderBehavior
  include CacheStoreCompressionBehavior
  include CacheStoreSerializerBehavior
  include CacheStoreFormatVersionBehavior
  include LocalCacheBehavior
  include CacheIncrementDecrementBehavior
  include CacheInstrumentationBehavior
  include CacheLoggingBehavior
  include EncodedKeyCacheBehavior
  include ConnectionPoolBehavior
  include FailureSafetyBehavior

  test "validate pool arguments" do
    assert_raises TypeError do
      ActiveSupport::Cache::MemCacheStore.new(pool: { size: [] })
    end

    assert_raises TypeError do
      ActiveSupport::Cache::MemCacheStore.new(pool: { timeout: [] })
    end

    ActiveSupport::Cache::MemCacheStore.new(pool: { size: "12", timeout: "1.5" })
  end

  test "instantiating the store doesn't connect to Memcache" do
    ActiveSupport::Cache::MemCacheStore.new("memcached://localhost:1")
  end

  # Overrides test from LocalCacheBehavior in order to stub out the cache clear
  # and replace it with a delete.
  def test_clear_also_clears_local_cache
    key = SecureRandom.uuid
    cache = lookup_store(raw: true)
    stub_called = false

    client(cache).stub(:flush_all, -> { stub_called = true; client.delete("#{@namespace}:#{key}") }) do
      cache.with_local_cache do
        cache.write(key, SecureRandom.alphanumeric)
        cache.clear
        assert_nil cache.read(key)
      end
      assert_nil cache.read(key)
    end
    assert stub_called
  end

  def test_short_key_normalization
    short_key = "a" * 250
    assert_equal short_key, @cache.send(:normalize_key, short_key, { namespace: nil })
  end

  def test_long_key_normalization
    long_key = "b" * 251
    normalized_key = @cache.send(:normalize_key, long_key, { namespace: nil })
    assert_equal 250, normalized_key.size
    assert_match(/^b+:hash:/, normalized_key)
  end

  def test_namespaced_key_normalization
    short_key = "a" * 250
    normalized_key = @cache.send(:normalize_key, short_key, { namespace: "ns" })
    assert_equal 250, normalized_key.size
    assert_match(/^ns:a+:hash:/, normalized_key)
  end

  def test_multibyte_string_key_normalization
    multibyte_key = "c" * 100 + ["01F60F".to_i(16)].pack("U*") + "c" * 149
    assert_equal 250, multibyte_key.size
    assert_equal 253, multibyte_key.bytes.size
    normalized_key = @cache.send(:normalize_key, multibyte_key, { namespace: nil })
    assert_equal 250, normalized_key.bytes.size
    assert_match(/^c{100}%F0%9F%98%8Fc+:hash:[[:print:]]+$/, normalized_key)
  end

  def test_whole_key_digest_on_normalization
    key_one = "d" * 1000 + "a"
    key_two = "d" * 1000 + "b"
    normalized_one = @cache.send(:normalize_key, key_one, { namespace: nil })
    normalized_two = @cache.send(:normalize_key, key_two, { namespace: nil })

    assert_equal 250, normalized_one.bytes.size
    assert_equal 250, normalized_two.bytes.size
    assert_not_equal normalized_one, normalized_two
  end

  def test_raw_values
    cache = lookup_store(raw: true)
    cache.write("foo", 2)
    assert_equal "2", cache.read("foo")
  end

  def test_raw_read_entry_compression
    cache = lookup_store(raw: true)
    cache.write("foo", 2)

    assert_not_called_on_instance_of ActiveSupport::Cache::Entry, :compressed do
      cache.read("foo")
    end
  end

  def test_raw_values_with_marshal
    cache = lookup_store(raw: true)
    cache.write("foo", Marshal.dump([]))
    assert_equal Marshal.dump([]), cache.read("foo")
  end

  def test_local_cache_raw_values
    cache = lookup_store(raw: true)
    cache.with_local_cache do
      cache.write("foo", 2)
      assert_equal "2", cache.read("foo")
    end
  end

  def test_increment_unset_key
    assert_equal 1, @cache.increment("foo")
    assert_equal "1", @cache.read("foo", raw: true)
  end

  def test_write_expires_at
    cache = lookup_store(raw: true, namespace: nil)

    Time.stub(:now, Time.now) do
      assert_called_with client(cache), :set, ["key_with_expires_at", "bar", 30 * 60], namespace: nil, pool: false, raw: true, compress_threshold: 1024, expires_in: 1800.0, socket_timeout: 60 do
        cache.write("key_with_expires_at", "bar", expires_at: 30.minutes.from_now)
      end
    end
  end

  def test_write_with_unless_exist
    assert_equal true, @cache.write("foo", 1)
    assert_equal false, @cache.write("foo", 1, unless_exist: true)
  end

  def test_increment_expires_in
    cache = lookup_store(raw: true, namespace: nil)
    assert_called_with client(cache), :incr, [ "foo", 1, 60, 1 ] do
      cache.increment("foo", 1, expires_in: 60)
    end
  end

  def test_decrement_unset_key
    assert_equal 0, @cache.decrement("foo")
    assert_equal "0", @cache.read("foo", raw: true)
  end

  def test_decrement_expires_in
    cache = lookup_store(raw: true, namespace: nil)
    assert_called_with client(cache), :decr, [ "foo", 1, 60, 0 ] do
      cache.decrement("foo", 1, expires_in: 60)
    end
  end

  def test_dalli_cache_nils
    cache = lookup_store(cache_nils: false)
    cache.fetch("nil_foo") { nil }
    assert_equal "bar", cache.fetch("nil_foo") { "bar" }

    cache1 = lookup_store(cache_nils: true)
    cache1.fetch("not_nil_foo") { nil }
    assert_nil cache.fetch("not_nil_foo") { "bar" }
  end

  def test_local_cache_raw_values_with_marshal
    cache = lookup_store(raw: true)
    cache.with_local_cache do
      cache.write("foo", Marshal.dump([]))
      assert_equal Marshal.dump([]), cache.read("foo")
    end
  end

  def test_read_should_return_a_different_object_id_each_time_it_is_called
    @cache.write("foo", "bar")
    value = @cache.read("foo")
    assert_not_equal value.object_id, @cache.read("foo").object_id
    value << "bingo"
    assert_not_equal value, @cache.read("foo")
  end

  def test_no_compress_when_below_threshold
    cache = lookup_store(compress: true, compress_threshold: 10.kilobytes)
    val = random_string(2.kilobytes)
    compressed = Zlib::Deflate.deflate(val)

    assert_called(
      Zlib::Deflate,
      :deflate,
      "Memcached writes should not compress when below compress threshold.",
      times: 0,
      returns: compressed
    ) do
      cache.write("foo", val)
    end
  end

  def test_no_multiple_compress
    cache = lookup_store(compress: true)
    val = random_string(100.kilobytes)
    compressed = Zlib::Deflate.deflate(val)

    assert_called(
      Zlib,
      :deflate,
      "Memcached writes should not perform duplicate compression.",
      times: 1,
      returns: compressed
    ) do
      cache.write("foo", val)
    end
  end

  def test_unless_exist_expires_when_configured
    cache = lookup_store(namespace: nil)

    assert_called_with client(cache), :add, ["foo", Object, 1], namespace: nil, pool: false, compress_threshold: 1024, expires_in: 1, socket_timeout: 60, unless_exist: true do
      cache.write("foo", "bar", expires_in: 1, unless_exist: true)
    end
  end

  def test_forwards_string_addresses_if_present
    expected_addresses = ["first", "second"]
    cache = lookup_store(expected_addresses)

    assert_equal expected_addresses, servers(cache)
  end

  def test_falls_back_to_localhost_if_no_address_provided_and_memcache_servers_undefined
    with_memcache_servers_environment_variable(nil) do
      cache = lookup_store

      assert_equal ["127.0.0.1:11211"], servers(cache)
    end
  end

  def test_falls_back_to_localhost_if_address_provided_as_nil
    with_memcache_servers_environment_variable(nil) do
      cache = lookup_store(nil)

      assert_equal ["127.0.0.1:11211"], servers(cache)
    end
  end

  def test_falls_back_to_localhost_if_no_address_provided_and_memcache_servers_defined
    with_memcache_servers_environment_variable("custom_host") do
      cache = lookup_store

      assert_equal ["custom_host"], servers(cache)
    end
  end

  def test_can_load_raw_values_from_dalli_store
    key = "test-with-value-the-way-the-dalli-store-did"

    @cache.instance_variable_get(:@data).with { |c| c.set(@cache.send(:normalize_key, key, nil), "value", 0, compress: false) }
    assert_nil @cache.read(key)
    assert_equal "value", @cache.fetch(key) { "value" }
  end

  def test_can_load_raw_falsey_values_from_dalli_store
    key = "test-with-false-value-the-way-the-dalli-store-did"

    @cache.instance_variable_get(:@data).with { |c| c.set(@cache.send(:normalize_key, key, nil), false, 0, compress: false) }
    assert_nil @cache.read(key)
    assert_equal false, @cache.fetch(key) { false }
  end

  def test_can_load_raw_values_from_dalli_store_with_local_cache
    key = "test-with-value-the-way-the-dalli-store-did-with-local-cache"

    @cache.instance_variable_get(:@data).with { |c| c.set(@cache.send(:normalize_key, key, nil), "value", 0, compress: false) }
    @cache.with_local_cache do
      assert_nil @cache.read(key)
      assert_equal "value", @cache.fetch(key) { "value" }
    end
  end

  def test_can_load_raw_falsey_values_from_dalli_store_with_local_cache
    key = "test-with-false-value-the-way-the-dalli-store-did-with-local-cache"

    @cache.instance_variable_get(:@data).with { |c| c.set(@cache.send(:normalize_key, key, nil), false, 0, compress: false) }
    @cache.with_local_cache do
      assert_nil @cache.read(key)
      assert_equal false, @cache.fetch(key) { false }
    end
  end

  def test_can_read_multi_entries_raw_values_from_dalli_store
    key = "test-with-nil-value-the-way-the-dalli-store-did"

    @cache.instance_variable_get(:@data).with { |c| c.set(@cache.send(:normalize_key, key, nil), nil, 0, compress: false) }
    assert_equal({}, @cache.send(:read_multi_entries, [key]))
  end

  def test_pool_options_work
    cache = ActiveSupport::Cache.lookup_store(:mem_cache_store, pool: { size: 2, timeout: 1 })
    pool = cache.instance_variable_get(:@data) # loads 'connection_pool' gem
    assert_kind_of ::ConnectionPool, pool
    assert_equal 2, pool.size
    assert_equal 1, pool.instance_variable_get(:@timeout)
  end

  def test_connection_pooling_by_default
    cache = ActiveSupport::Cache.lookup_store(:mem_cache_store)
    pool = cache.instance_variable_get(:@data)
    assert_kind_of ::ConnectionPool, pool
    assert_equal 5, pool.size
    assert_equal 5, pool.instance_variable_get(:@timeout)
  end

  private
    def random_string(length)
      (0...length).map { (65 + rand(26)).chr }.join
    end

    def store
      [:mem_cache_store]
    end

    def emulating_latency
      old_client = Dalli.send(:remove_const, :Client)
      Dalli.const_set(:Client, SlowDalliClient)

      yield
    ensure
      Dalli.send(:remove_const, :Client)
      Dalli.const_set(:Client, old_client)
    end

    def emulating_unavailability
      old_server = Dalli::Protocol.send(:remove_const, :Binary)
      Dalli::Protocol.const_set(:Binary, UnavailableDalliServer)

      yield ActiveSupport::Cache::MemCacheStore.new
    ensure
      Dalli::Protocol.send(:remove_const, :Binary)
      Dalli::Protocol.const_set(:Binary, old_server)
    end

    def servers(cache = @cache)
      if client(cache).instance_variable_defined?(:@normalized_servers)
        client(cache).instance_variable_get(:@normalized_servers)
      else
        client(cache).instance_variable_get(:@servers)
      end
    end

    def client(cache = @cache)
      cache.instance_variable_get(:@data)
    end

    def with_memcache_servers_environment_variable(value)
      original_value = ENV["MEMCACHE_SERVERS"]
      ENV["MEMCACHE_SERVERS"] = value
      yield
    ensure
      if original_value.nil?
        ENV.delete("MEMCACHE_SERVERS")
      else
        ENV["MEMCACHE_SERVERS"] = original_value
      end
    end
end
