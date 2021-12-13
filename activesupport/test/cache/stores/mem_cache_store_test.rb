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

  begin
    servers = ENV["MEMCACHE_SERVERS"] || "localhost:11211"
    ss = Dalli::Client.new(servers).stats
    raise Dalli::DalliError unless ss[servers] || ss[servers + ":11211"]

    MEMCACHE_UP = true
  rescue Dalli::DalliError
    $stderr.puts "Skipping memcached tests. Start memcached and try again."
    MEMCACHE_UP = false
  end

  def lookup_store(options = {})
    ActiveSupport::Cache.lookup_store(*store, { namespace: @namespace }.merge(options))
  end

  def setup
    skip "memcache server is not up" unless MEMCACHE_UP

    @namespace = "test-#{SecureRandom.hex}"
    @cache = lookup_store(expires_in: 60)
    @peek = lookup_store
    @cache.logger = ActiveSupport::Logger.new(File::NULL)
  end

  include CacheStoreBehavior
  include CacheStoreVersionBehavior
  include CacheStoreCoderBehavior
  include LocalCacheBehavior
  include CacheIncrementDecrementBehavior
  include CacheInstrumentationBehavior
  include EncodedKeyCacheBehavior
  include AutoloadingCacheBehavior
  include ConnectionPoolBehavior
  include FailureSafetyBehavior

  # Overrides test from LocalCacheBehavior in order to stub out the cache clear
  # and replace it with a delete.
  def test_clear_also_clears_local_cache
    key = "#{@namespace}:foo"
    client.stub(:flush_all, -> { client.delete(key) }) do
      super
    end
  end

  def test_raw_values
    cache = lookup_store(raw: true)
    cache.write("foo", 2)
    assert_equal "2", cache.read("foo")
  end

  def test_raw_read_entry_compression
    cache = lookup_store(raw: true)
    cache.write("foo", 2)

    assert_not_called_on_instance_of ActiveSupport::Cache::Entry, :compress! do
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

  def test_increment_expires_in
    cache = lookup_store(raw: true, namespace: nil)
    assert_called_with client(cache), :incr, [ "foo", 1, 60 ] do
      cache.increment("foo", 1, expires_in: 60)
    end
  end

  def test_decrement_expires_in
    cache = lookup_store(raw: true, namespace: nil)
    assert_called_with client(cache), :decr, [ "foo", 1, 60 ] do
      cache.decrement("foo", 1, expires_in: 60)
    end
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
      Zlib::Deflate,
      :deflate,
      "Memcached writes should not perform duplicate compression.",
      times: 1,
      returns: compressed
    ) do
      cache.write("foo", val)
    end
  end

  def test_unless_exist_expires_when_configured
    cache = ActiveSupport::Cache.lookup_store(:mem_cache_store)
    assert_called_with client(cache), :add, [ "foo", ActiveSupport::Cache::Entry, 1, Hash ] do
      cache.write("foo", "bar", expires_in: 1, unless_exist: true)
    end
  end

  def test_uses_provided_dalli_client_if_present
    cache = ActiveSupport::Cache.lookup_store(:mem_cache_store, Dalli::Client.new("custom_host"))

    assert_equal ["custom_host"], servers(cache)
  end

  def test_forwards_string_addresses_if_present
    expected_addresses = ["first", "second"]
    cache = ActiveSupport::Cache.lookup_store(:mem_cache_store, expected_addresses)

    assert_equal expected_addresses, servers(cache)
  end

  def test_falls_back_to_localhost_if_no_address_provided_and_memcache_servers_undefined
    with_memcache_servers_environment_variable(nil) do
      cache = ActiveSupport::Cache.lookup_store(:mem_cache_store)

      assert_equal ["127.0.0.1:11211"], servers(cache)
    end
  end

  def test_falls_back_to_localhost_if_address_provided_as_nil
    with_memcache_servers_environment_variable(nil) do
      cache = ActiveSupport::Cache.lookup_store(:mem_cache_store, nil)

      assert_equal ["127.0.0.1:11211"], servers(cache)
    end
  end

  def test_falls_back_to_localhost_if_no_address_provided_and_memcache_servers_defined
    with_memcache_servers_environment_variable("custom_host") do
      cache = ActiveSupport::Cache.lookup_store(:mem_cache_store)

      assert_equal ["custom_host"], servers(cache)
    end
  end

  def test_large_string_with_default_compression_settings
    assert_compressed(LARGE_STRING)
  end

  def test_large_object_with_default_compression_settings
    assert_compressed(LARGE_OBJECT)
  end

  def test_can_read_and_write_falsy_value
    key = "test-with-false-value-through-public-api"

    @cache.write(key, false)
    assert_equal false, @cache.read(key)
  end

  def test_can_load_raw_values_from_dalli_store
    key = "test-with-false-value-the-way-the-dalli-store-did"

    @cache.instance_variable_get(:@data).with { |c| c.set(@cache.send(:normalize_key, key, nil), false, 0, compress: false) }
    assert_equal false, @cache.read(key)
  end

  def test_can_read_and_write_falsy_value_with_local_cache
    key = "test-with-false-value-through-public-api"

    @cache.write(key, false)
    @cache.with_local_cache do
      assert_equal false, @cache.read(key)
    end
  end

  def test_can_load_raw_values_from_dalli_store_with_local_cache
    key = "test-with-false-value-the-way-the-dalli-store-did"

    @cache.instance_variable_get(:@data).with { |c| c.set(@cache.send(:normalize_key, key, nil), false, 0, compress: false) }
    @cache.with_local_cache do
      assert_equal false, @cache.read(key)
    end
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
      client(cache).instance_variable_get(:@servers)
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
