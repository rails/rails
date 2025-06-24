# frozen_string_literal: true

module CacheStoreCoderBehavior
  class SpyCoder
    attr_reader :dumped_entries, :loaded_entries, :dump_compressed_entries

    def initialize
      @dumped_entries = []
      @loaded_entries = []
      @dump_compressed_entries = []
    end

    def dump(entry)
      @dumped_entries << entry
      Marshal.dump(entry)
    end

    def load(payload)
      entry = Marshal.load(payload)
      @loaded_entries << entry
      entry
    end

    def dump_compressed(entry, threshold)
      if threshold == 0
        @dump_compressed_entries << entry
        Marshal.dump(entry)
      else
        dump(entry)
      end
    end
  end

  def test_coder_receive_the_entry_on_write
    coder = SpyCoder.new
    @store = lookup_store(coder: coder)
    @store.write("foo", "bar")
    assert_equal 1, coder.dumped_entries.size
    entry = coder.dumped_entries.first
    assert_instance_of ActiveSupport::Cache::Entry, entry
    assert_equal "bar", entry.value
  end

  def test_coder_receive_the_entry_on_read
    coder = SpyCoder.new
    @store = lookup_store(coder: coder)
    @store.write("foo", "bar")
    @store.read("foo")
    assert_equal 1, coder.loaded_entries.size
    entry = coder.loaded_entries.first
    assert_instance_of ActiveSupport::Cache::Entry, entry
    assert_equal "bar", entry.value
  end

  def test_coder_receive_the_entry_on_read_multi
    coder = SpyCoder.new
    @store = lookup_store(coder: coder)
    @store.write_multi({ "foo" => "bar", "egg" => "spam" })
    @store.read_multi("foo", "egg")
    assert_equal 2, coder.loaded_entries.size
    entry = coder.loaded_entries.first
    assert_instance_of ActiveSupport::Cache::Entry, entry
    assert_equal "bar", entry.value

    entry = coder.loaded_entries[1]
    assert_instance_of ActiveSupport::Cache::Entry, entry
    assert_equal "spam", entry.value
  end

  def test_coder_receive_the_entry_on_write_multi
    coder = SpyCoder.new
    @store = lookup_store(coder: coder)
    @store.write_multi({ "foo" => "bar", "egg" => "spam" })
    assert_equal 2, coder.dumped_entries.size
    entry = coder.dumped_entries.first
    assert_instance_of ActiveSupport::Cache::Entry, entry
    assert_equal "bar", entry.value

    entry = coder.dumped_entries[1]
    assert_instance_of ActiveSupport::Cache::Entry, entry
    assert_equal "spam", entry.value
  end

  def test_coder_does_not_receive_the_entry_on_read_miss
    coder = SpyCoder.new
    @store = lookup_store(coder: coder)
    @store.read("foo")
    assert_equal 0, coder.loaded_entries.size
  end

  def test_nil_coder_bypasses_serialization
    @store = lookup_store(coder: nil)
    entry = ActiveSupport::Cache::Entry.new("value")
    assert_same entry, @store.send(:serialize_entry, entry)
  end

  def test_coder_is_used_during_handle_expired_entry_when_expired
    coder = SpyCoder.new
    @store = lookup_store(coder: coder)
    @store.write("foo", "bar", expires_in: 1.second)
    assert_equal 0, coder.loaded_entries.size
    assert_equal 1, coder.dumped_entries.size

    travel_to(2.seconds.from_now) do
      val = @store.fetch(
          "foo",
          race_condition_ttl: 5,
          compress: true,
          compress_threshold: 0
        ) { "baz" }
      assert_equal "baz", val
      assert_equal 1, coder.loaded_entries.size # 1 read in fetch
      assert_equal "bar", coder.loaded_entries.first.value
      assert_equal 1, coder.dumped_entries.size # did not change from original write
      assert_equal 2, coder.dump_compressed_entries.size # 1 write the expired entry handler, 1 in fetch
      assert_equal "bar", coder.dump_compressed_entries.first.value
      assert_equal "baz", coder.dump_compressed_entries.last.value
    end
  end
end
