# frozen_string_literal: true

module CacheStoreCoderBehavior
  class SpyCoder
    attr_reader :dumped_entries, :loaded_entries

    def initialize
      @dumped_entries = []
      @loaded_entries = []
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
  end

  def test_coder_recieve_the_entry_on_write
    coder = SpyCoder.new
    @store = lookup_store(coder: coder)
    @store.write("foo", "bar")
    assert_equal 1, coder.dumped_entries.size
    entry = coder.dumped_entries.first
    assert_instance_of ActiveSupport::Cache::Entry, entry
    assert_equal "bar", entry.value
  end

  def test_coder_recieve_the_entry_on_read
    coder = SpyCoder.new
    @store = lookup_store(coder: coder)
    @store.write("foo", "bar")
    @store.read("foo")
    assert_equal 1, coder.loaded_entries.size
    entry = coder.loaded_entries.first
    assert_instance_of ActiveSupport::Cache::Entry, entry
    assert_equal "bar", entry.value
  end

  def test_coder_recieve_the_entry_on_read_multi
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

  def test_coder_recieve_the_entry_on_write_multi
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

  def test_coder_does_not_recieve_the_entry_on_read_miss
    coder = SpyCoder.new
    @store = lookup_store(coder: coder)
    @store.read("foo")
    assert_equal 0, coder.loaded_entries.size
  end
end
