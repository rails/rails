# frozen_string_literal: true

require_relative "../abstract_unit"
require "active_support/message_pack"
require_relative "shared_serializer_tests"

class MessagePackCacheSerializerTest < ActiveSupport::TestCase
  include MessagePackSharedSerializerTests

  test "uses #to_msgpack_ext and ::from_msgpack_ext to roundtrip unregistered objects" do
    assert_roundtrip DefinesFromMsgpackExt.new("foo")
  end

  test "uses #as_json and ::json_create to roundtrip unregistered objects" do
    assert_roundtrip DefinesJsonCreate.new("foo")
  end

  test "raises error when unable to serialize an unregistered object" do
    assert_raises ActiveSupport::MessagePack::UnserializableObjectError do
      dump(Unserializable.new("foo"))
    end
  end

  test "raises error when serializing an unregistered object with an anonymous class" do
    assert_raises ActiveSupport::MessagePack::UnserializableObjectError do
      dump(Class.new(DefinesFromMsgpackExt).new("foo"))
    end
  end

  test "integrates with ActiveSupport::Cache" do
    with_cache do |cache|
      value = DefinesFromMsgpackExt.new("foo")
      cache.write("key", value)
      assert_equal value, cache.read("key")
    end
  end

  test "treats missing class as a cache miss" do
    klass = Class.new(DefinesFromMsgpackExt)
    def klass.name; "DoesNotActuallyExist"; end

    with_cache do |cache|
      value = klass.new("foo")
      cache.write("key", value)
      assert_nil cache.read("key")
    end
  end

  test "supports compression" do
    entry = ActiveSupport::Cache::Entry.new(["foo"] * 100)
    uncompressed = serializer.dump(entry)
    compressed = serializer.dump_compressed(entry, 1)

    assert_operator compressed.bytesize, :<, uncompressed.bytesize
    assert_equal serializer.load(uncompressed).value, serializer.load(compressed).value

    with_cache(compress_threshold: 1) do |cache|
      assert_equal compressed, cache.send(:serialize_entry, entry)
    end
  end

  private
    def serializer
      ActiveSupport::MessagePack::CacheSerializer
    end

    def dump(object)
      super(ActiveSupport::Cache::Entry.new(object))
    end

    def load(dumped)
      super.value
    end

    def with_cache(**options, &block)
      Dir.mktmpdir do |dir|
        block.call(ActiveSupport::Cache::FileStore.new(dir, coder: serializer, **options))
      end
    end

    class HasValue
      attr_reader :value

      def initialize(value)
        @value = value
      end

      def ==(other)
        self.class == other.class && value == other.value
      end
    end

    class DefinesJsonCreate < HasValue
      def self.json_create(hash)
        DefinesJsonCreate.new(hash["as_json"])
      end

      def as_json
        { "as_json" => value }
      end
    end

    class DefinesFromMsgpackExt < DefinesJsonCreate
      def self.from_msgpack_ext(string)
        DefinesFromMsgpackExt.new(string.chomp!("msgpack_ext"))
      end

      def to_msgpack_ext
        value + "msgpack_ext"
      end
    end

    class Unserializable < HasValue
      def as_json
        {}
      end

      def to_msgpack_ext
        ""
      end
    end
end
