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

  def test_coder_receive_the_entry_on_write
    coder = SpyCoder.new
    @store = lookup_store(coder: coder)
    key = SecureRandom.uuid
    value = SecureRandom.alphanumeric

    @store.write(key, value)
    assert_equal 1, coder.dumped_entries.size
    entry = coder.dumped_entries.first
    assert_instance_of ActiveSupport::Cache::Entry, entry
    assert_equal value, entry.value
  end

  def test_coder_receive_the_entry_on_read
    coder = SpyCoder.new
    @store = lookup_store(coder: coder)
    key = SecureRandom.uuid
    value = SecureRandom.alphanumeric

    @store.write(key, value)
    @store.read(key)
    assert_equal 1, coder.loaded_entries.size
    entry = coder.loaded_entries.first
    assert_instance_of ActiveSupport::Cache::Entry, entry
    assert_equal value, entry.value
  end

  def test_coder_receive_the_entry_on_read_multi
    coder = SpyCoder.new
    @store = lookup_store(coder: coder)
    key = SecureRandom.uuid
    value = SecureRandom.alphanumeric
    other_key = SecureRandom.uuid
    other_value = SecureRandom.alphanumeric

    @store.write_multi({ key => value, other_key => other_value })
    @store.read_multi(key, other_key)
    assert_equal 2, coder.loaded_entries.size
    entry = coder.loaded_entries.first
    assert_instance_of ActiveSupport::Cache::Entry, entry
    assert_equal value, entry.value

    entry = coder.loaded_entries[1]
    assert_instance_of ActiveSupport::Cache::Entry, entry
    assert_equal other_value, entry.value
  end

  def test_coder_receive_the_entry_on_write_multi
    coder = SpyCoder.new
    @store = lookup_store(coder: coder)
    key = SecureRandom.uuid
    value = SecureRandom.alphanumeric
    other_key = SecureRandom.uuid
    other_value = SecureRandom.alphanumeric

    @store.write_multi({ key => value, other_key => other_value })
    assert_equal 2, coder.dumped_entries.size
    entry = coder.dumped_entries.first
    assert_instance_of ActiveSupport::Cache::Entry, entry
    assert_equal value, entry.value

    entry = coder.dumped_entries[1]
    assert_instance_of ActiveSupport::Cache::Entry, entry
    assert_equal other_value, entry.value
  end

  def test_coder_does_not_receive_the_entry_on_read_miss
    coder = SpyCoder.new
    @store = lookup_store(coder: coder)

    @store.read(SecureRandom.uuid)
    assert_equal 0, coder.loaded_entries.size
  end
end
