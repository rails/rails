# frozen_string_literal: true

require "abstract_unit"
require "active_support/cache"
require "active_support/cache/streaming_compressor"

class CacheStreamingCompressorTest < ActiveSupport::TestCase
  def described_class
    ActiveSupport::Cache::StreamingCompressor
  end

  def assert_load(value)
    dumped = Zlib.deflate(Marshal.dump(value))
    assert_equal(value, described_class.load(dumped))
  end

  def assert_dump(value, **options)
    dumped = described_class.dump(value, **options)
    assert_equal(value, Marshal.load(Zlib.inflate(dumped)))
  end

  def test_load
    assert_load SecureRandom.hex(1_000_000)
    assert_load "a" * 100_000_00
    assert_load "a" * 1_000_000
    assert_load [{ test: "value" }]
  end

  def test_dump
    assert_dump SecureRandom.hex(1_000_000)
    assert_dump "a" * 100
    assert_dump "a" * 1_000_000
    assert_dump [{ test: "a" * 50 }]
  end

  def test_dump_with_compress_threshold
    buffer_size = described_class::DEFLATE_BUFFER_SIZE

    threshold = 700
    assert_nil described_class.dump("a" * 600, compress_threshold: threshold)
    assert_dump "a" * 800, compress_threshold: threshold
    assert_dump "a" * buffer_size * 3, compress_threshold: threshold

    threshold = buffer_size + 200
    assert_nil described_class.dump("a" * buffer_size, compress_threshold: threshold)
    assert_dump "a" * threshold, compress_threshold: threshold
    assert_dump "a" * buffer_size * 3, compress_threshold: threshold
  end

  def test_concurrent_environment
    Array.new(5) { |i| i.to_s * 1_000_000 }.map do |value|
      Thread.new do
        assert_equal(value, described_class.load(described_class.dump(value)))
      end
    end.each(&:join)
  end
end
