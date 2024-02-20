# frozen_string_literal: true

require_relative "../abstract_unit"
require "active_support/core_ext/object/with"

class CacheSerializerWithFallbackTest < ActiveSupport::TestCase
  FORMATS = ActiveSupport::Cache::SerializerWithFallback::SERIALIZERS.keys
  LEGACY_FORMATS = [:passthrough, :marshal_7_0]

  setup do
    @entry = ActiveSupport::Cache::Entry.new(
      [{ a_boolean: false, a_number: 123, a_string: "x" * 40 }], expires_in: 100, version: "v42"
    )
  end

  FORMATS.product(FORMATS - LEGACY_FORMATS) do |loader, dumper|
    test "#{loader.inspect} serializer can load #{dumper.inspect} dump" do
      dumped = serializer(dumper).dump(@entry.value)
      assert_equal @entry.value, serializer(loader).load(dumped)
    end
  end

  FORMATS.product(LEGACY_FORMATS) do |loader, dumper|
    test "#{loader.inspect} serializer can load #{dumper.inspect} dump" do
      dumped = serializer(dumper).dump(@entry)
      assert_entry @entry, serializer(loader).load(dumped)
    end
  end

  FORMATS.each do |format|
    test "#{format.inspect} serializer handles unrecognized payloads gracefully" do
      assert_nil serializer(format).load(Object.new)
      assert_nil serializer(format).load("")
    end

    test "#{format.inspect} serializer logs unrecognized payloads" do
      assert_logs(/unrecognized/i) { serializer(format).load(Object.new) }
      assert_logs(/unrecognized/i) { serializer(format).load("") }
    end
  end

  LEGACY_FORMATS.each do |format|
    test "#{format.inspect} serializer can compress entries" do
      compressed = serializer(format).dump_compressed(@entry, 1)
      uncompressed = serializer(format).dump_compressed(@entry, 100_000)

      assert_operator compressed.bytesize, :<, uncompressed.bytesize
      assert_entry @entry, serializer(format).load(compressed)
      assert_entry @entry, serializer(format).load(uncompressed)
    end
  end

  test ":message_pack serializer handles missing class gracefully" do
    klass = Class.new do
      def self.name; "DoesNotActuallyExist"; end
      def self.from_msgpack_ext(string); self.new; end
      def to_msgpack_ext; ""; end
    end

    dumped = serializer(:message_pack).dump(klass.new)
    assert_not_nil dumped
    assert_nil serializer(:message_pack).load(dumped)
  end

  test "raises on invalid format name" do
    assert_raises KeyError do
      ActiveSupport::Cache::SerializerWithFallback[:invalid_format]
    end
  end

  private
    def serializer(format)
      ActiveSupport::Cache::SerializerWithFallback[format]
    end

    def assert_entry(expected, actual)
      assert_equal \
        [expected.value, expected.version, expected.expires_at],
        [actual.value, actual.version, actual.expires_at]
    end

    def assert_logs(pattern, &block)
      io = StringIO.new
      ActiveSupport::Cache::Store.with(logger: Logger.new(io), &block)
      assert_match pattern, io.string
    end
end
