# frozen_string_literal: true

module CacheStoreCoderBehavior
  class SpyCoder
    attr_reader :dumped_entries, :deserialize_entries, :serializer

    def initialize(serializer)
      @dumped_entries = []
      @deserialize_entries = []
      @serializer = serializer
    end

    def dump(entry)
      @dumped_entries << entry
      serialize(entry)
    end

    def load(payload)
      entry = deserialize(payload)
      @deserialize_entries << entry
      entry
    end

    private
      def serialize(entry)
        serializer == :json ? ActiveSupport::JSON.encode(entry.pack) : Marshal.dump(entry)
      end
      
      def deserialize(payload)
        return Marshal.load(payload) unless serializer == :json
        
        entry = ActiveSupport::JSON.decode(payload, symbolize_names: true)
        ActiveSupport::Cache::Entry.unpack(entry)
      end
  end

  SERIALIZERS = [
    :marshal,
    :json
  ].freeze
 
  SERIALIZERS.each do |serializer|
    define_method "test_coder_with_#{serializer}_serializer_receive_the_entry_on_write" do
      coder = SpyCoder.new(serializer)
      @store = lookup_store(coder: coder)
      @store.write("foo", "bar")
      assert_equal 1, coder.dumped_entries.size
      entry = coder.dumped_entries.first
      assert_instance_of ActiveSupport::Cache::Entry, entry
      assert_equal "bar", entry.value
    end

    define_method "test_coder_with_#{serializer}_serializer_receive_the_entry_on_read" do
      coder = SpyCoder.new(serializer)
      @store = lookup_store(coder: coder)
      @store.write("foo", "bar")
      @store.read("foo")
      assert_equal 1, coder.deserialize_entries.size
      entry = coder.deserialize_entries.first
      assert_instance_of ActiveSupport::Cache::Entry, entry
      assert_equal "bar", entry.value
    end

    define_method "test_coder_with_#{serializer}_serializer_receive_the_entry_on_read_multi" do
      coder = SpyCoder.new(serializer)
      @store = lookup_store(coder: coder)
      @store.write_multi({ "foo" => "bar", "egg" => "spam" })
      @store.read_multi("foo", "egg")
      assert_equal 2, coder.deserialize_entries.size
      entry = coder.deserialize_entries.first
      assert_instance_of ActiveSupport::Cache::Entry, entry
      assert_equal "bar", entry.value

      entry = coder.deserialize_entries[1]
      assert_instance_of ActiveSupport::Cache::Entry, entry
      assert_equal "spam", entry.value
    end

    define_method "test_coder_with_#{serializer}_serializer_receive_the_entry_on_write_multi" do
      coder = SpyCoder.new(serializer)
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

    define_method "test_coder_with_#{serializer}_serializer_does_not_receive_the_entry_on_read_miss" do
      coder = SpyCoder.new(serializer)
      @store = lookup_store(coder: coder)
      @store.read("foo")
      assert_equal 0, coder.deserialize_entries.size
    end
  end
end
