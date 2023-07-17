# frozen_string_literal: true

require_relative "../abstract_unit"
require "active_support/core_ext/object/with"

class CacheSerializerWithFallbackTest < ActiveSupport::TestCase
  FORMATS = ActiveSupport::Cache::SerializerWithFallback::SERIALIZERS.keys

  setup do
    @entry = ActiveSupport::Cache::Entry.new(
      [{ a_boolean: false, a_number: 123, a_string: "x" * 40 }], expires_in: 100, version: "v42"
    )
  end

  FORMATS.product(FORMATS) do |load_format, dump_format|
    test "#{load_format.inspect} serializer can load #{dump_format.inspect} dump" do
      dumped = serializer(dump_format).dump(@entry)
      assert_entry @entry, serializer(load_format).load(dumped)
    end

    test "#{load_format.inspect} serializer can load #{dump_format.inspect} dump with compression" do
      compressed = serializer(dump_format).dump_compressed(@entry, 1)
      assert_entry @entry, serializer(load_format).load(compressed)

      uncompressed = serializer(dump_format).dump_compressed(@entry, 100_000)
      assert_entry @entry, serializer(load_format).load(uncompressed)
    end
  end

  FORMATS.each do |format|
    test "#{format.inspect} serializer can compress entries" do
      compressed = serializer(format).dump_compressed(@entry, 1)
      uncompressed = serializer(format).dump_compressed(@entry, 100_000)
      assert_operator compressed.bytesize, :<, uncompressed.bytesize
    end

    test "#{format.inspect} serializer handles unrecognized payloads gracefully" do
      assert_nil serializer(format).load(Object.new)
      assert_nil serializer(format).load("")
    end

    test "#{format.inspect} serializer logs unrecognized payloads" do
      assert_logs(/unrecognized/i) { serializer(format).load(Object.new) }
      assert_logs(/unrecognized/i) { serializer(format).load("") }
    end
  end

  (FORMATS - [:passthrough, :marshal_6_1, :marshal_7_0]).each do |format|
    test "#{format.inspect} serializer preserves version with bare string" do
      entry = ActiveSupport::Cache::Entry.new("abc", version: "123")
      assert_entry entry, roundtrip(format, entry)
    end

    test "#{format.inspect} serializer preserves expiration with bare string" do
      entry = ActiveSupport::Cache::Entry.new("abc", expires_in: 123)
      assert_entry entry, roundtrip(format, entry)
    end

    test "#{format.inspect} serializer preserves encoding of version with bare string" do
      [Encoding::UTF_8, Encoding::BINARY].each do |encoding|
        version = "123".encode(encoding)
        roundtripped = roundtrip(format, ActiveSupport::Cache::Entry.new("abc", version: version))
        assert_equal version.encoding, roundtripped.version.encoding
      end
    end

    test "#{format.inspect} serializer preserves encoding of bare string" do
      [Encoding::UTF_8, Encoding::BINARY, Encoding::US_ASCII].each do |encoding|
        string = "abc".encode(encoding)
        roundtripped = roundtrip(format, ActiveSupport::Cache::Entry.new(string))
        assert_equal string.encoding, roundtripped.value.encoding
      end
    end

    test "#{format.inspect} serializer dumps bare string with reduced overhead when possible" do
      string = "abc"
      options = { version: "123", expires_in: 123 }

      unsupported = string.encode(Encoding::WINDOWS_1252)
      unoptimized = serializer(format).dump(ActiveSupport::Cache::Entry.new(unsupported, **options))

      [Encoding::UTF_8, Encoding::BINARY, Encoding::US_ASCII].each do |encoding|
        supported = string.encode(encoding)
        optimized = serializer(format).dump(ActiveSupport::Cache::Entry.new(supported, **options))
        assert_operator optimized.size, :<, unoptimized.size
      end
    end

    test "#{format.inspect} serializer can compress bare strings" do
      entry = ActiveSupport::Cache::Entry.new("abc" * 100, version: "123", expires_in: 123)
      compressed = serializer(format).dump_compressed(entry, 1)
      uncompressed = serializer(format).dump_compressed(entry, 100_000)
      assert_operator compressed.bytesize, :<, uncompressed.bytesize
    end
  end

  [:passthrough, :marshal_6_1, :marshal_7_0].each do |format|
    test "#{format.inspect} serializer dumps bare string in a backward compatible way" do
      string = +"abc"
      string.instance_variable_set(:@baz, true)
      roundtripped = roundtrip(format, ActiveSupport::Cache::Entry.new(string))
      assert roundtripped.value.instance_variable_get(:@baz)
    end
  end

  test ":message_pack serializer handles missing class gracefully" do
    klass = Class.new do
      def self.name; "DoesNotActuallyExist"; end
      def self.from_msgpack_ext(string); self.new; end
      def to_msgpack_ext; ""; end
    end

    dumped = serializer(:message_pack).dump(ActiveSupport::Cache::Entry.new(klass.new))
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

    def roundtrip(format, entry)
      serializer(format).load(serializer(format).dump(entry))
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
