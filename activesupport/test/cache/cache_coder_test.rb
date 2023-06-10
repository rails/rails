# frozen_string_literal: true

require_relative "../abstract_unit"
require "active_support/core_ext/integer/time"

class CacheCoderTest < ActiveSupport::TestCase
  setup do
    @coder = ActiveSupport::Cache::Coder.new(Serializer, Compressor)
  end

  test "roundtrips entry" do
    ENTRIES.each do |entry|
      assert_entry entry, @coder.load(@coder.dump(entry))
    end
  end

  test "roundtrips entry when using compression" do
    ENTRIES.each do |entry|
      assert_entry entry, @coder.load(@coder.dump_compressed(entry, 1))
    end
  end

  test "compresses values that are larger than the threshold" do
    COMPRESSIBLE_ENTRIES.each do |entry|
      dumped = @coder.dump(entry)
      compressed = @coder.dump_compressed(entry, 1)

      assert_operator compressed.bytesize, :<, dumped.bytesize
    end
  end

  test "does not compress values that are smaller than the threshold" do
    COMPRESSIBLE_ENTRIES.each do |entry|
      dumped = @coder.dump(entry)
      not_compressed = @coder.dump_compressed(entry, 1_000_000)

      assert_equal dumped, not_compressed
    end
  end

  test "does not apply compression to incompressible values" do
    (ENTRIES - COMPRESSIBLE_ENTRIES).each do |entry|
      dumped = @coder.dump(entry)
      not_compressed = @coder.dump_compressed(entry, 1)

      assert_equal dumped, not_compressed
    end
  end

  test "loads dumped entries from original serializer" do
    ENTRIES.each do |entry|
      assert_entry entry, @coder.load(Serializer.dump(entry))
    end
  end

  test "matches output of original serializer when legacy_serializer: true" do
    @coder = ActiveSupport::Cache::Coder.new(Serializer, Compressor, legacy_serializer: true)

    ENTRIES.each do |entry|
      assert_equal Serializer.dump(entry), @coder.dump(entry)
      assert_equal Serializer.dump_compressed(entry, 1), @coder.dump_compressed(entry, 1)
    end
  end

  test "dumps bare strings with reduced overhead when possible" do
    unoptimized = @coder.dump(ActiveSupport::Cache::Entry.new("".encode(Encoding::WINDOWS_1252)))

    [Encoding::UTF_8, Encoding::BINARY, Encoding::US_ASCII].each do |encoding|
      optimized = @coder.dump(ActiveSupport::Cache::Entry.new("".encode(encoding)))
      assert_operator optimized.size, :<, unoptimized.size
    end
  end

  private
    module Serializer
      extend self

      def dump(entry)
        "SERIALIZED:" + Marshal.dump(entry)
      end

      def dump_compressed(*)
        "via Serializer#dump_compressed"
      end

      def load(dumped)
        Marshal.load(dumped.delete_prefix!("SERIALIZED:"))
      end
    end

    module Compressor
      extend self

      def deflate(string)
        "COMPRESSED:" + Zlib.deflate(string)
      end

      def inflate(deflated)
        Zlib.inflate(deflated.delete_prefix!("COMPRESSED:"))
      end
    end

    STRING = "x" * 100
    COMPRESSIBLE_VALUES = [
      { string: STRING },
      STRING,
      STRING.encode(Encoding::BINARY),
      STRING.encode(Encoding::US_ASCII),
      STRING.encode(Encoding::WINDOWS_1252),
    ]
    VALUES = [nil, true, 1, "", "ümlaut", [*0..255].pack("C*"), *COMPRESSIBLE_VALUES]
    VERSIONS = [nil, "", "ümlaut", [*0..255].pack("C*"), "x" * 256]
    EXPIRIES = [nil, 0, 100.years]

    ENTRIES = VALUES.product(VERSIONS, EXPIRIES).map do |value, version, expires_in|
      ActiveSupport::Cache::Entry.new(value, version: version, expires_in: expires_in).freeze
    end

    COMPRESSIBLE_ENTRIES = ENTRIES.select { |entry| COMPRESSIBLE_VALUES.include?(entry.value) }

    def assert_entry(expected, actual)
      assert_equal \
        [expected.value, expected.version, expected.expires_at],
        [actual.value, actual.version, actual.expires_at]
    end
end
