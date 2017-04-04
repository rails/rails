require "abstract_unit"
require "active_support/core_ext/object/blank"

class GzipTest < ActiveSupport::TestCase
  def test_compress_should_decompress_to_the_same_value
    assert_equal "Hello World", ActiveSupport::Gzip.decompress(ActiveSupport::Gzip.compress("Hello World"))
    assert_equal "Hello World", ActiveSupport::Gzip.decompress(ActiveSupport::Gzip.compress("Hello World", Zlib::NO_COMPRESSION))
    assert_equal "Hello World", ActiveSupport::Gzip.decompress(ActiveSupport::Gzip.compress("Hello World", Zlib::BEST_SPEED))
    assert_equal "Hello World", ActiveSupport::Gzip.decompress(ActiveSupport::Gzip.compress("Hello World", Zlib::BEST_COMPRESSION))
    assert_equal "Hello World", ActiveSupport::Gzip.decompress(ActiveSupport::Gzip.compress("Hello World", nil, Zlib::FILTERED))
    assert_equal "Hello World", ActiveSupport::Gzip.decompress(ActiveSupport::Gzip.compress("Hello World", nil, Zlib::HUFFMAN_ONLY))
    assert_equal "Hello World", ActiveSupport::Gzip.decompress(ActiveSupport::Gzip.compress("Hello World", nil, nil))
  end

  def test_compress_should_return_a_binary_string
    compressed = ActiveSupport::Gzip.compress("")

    assert_equal Encoding.find("binary"), compressed.encoding
    assert !compressed.blank?, "a compressed blank string should not be blank"
  end

  def test_compress_should_return_gzipped_string_by_compression_level
    source_string = "Hello World" * 100

    gzipped_by_speed = ActiveSupport::Gzip.compress(source_string, Zlib::BEST_SPEED)
    assert_equal 1, Zlib::GzipReader.new(StringIO.new(gzipped_by_speed)).level

    gzipped_by_best_compression = ActiveSupport::Gzip.compress(source_string, Zlib::BEST_COMPRESSION)
    assert_equal 9, Zlib::GzipReader.new(StringIO.new(gzipped_by_best_compression)).level

    assert_equal true, (gzipped_by_best_compression.bytesize < gzipped_by_speed.bytesize)
  end

  def test_decompress_checks_crc
    compressed = ActiveSupport::Gzip.compress("Hello World")
    first_crc_byte_index = compressed.bytesize - 8
    compressed.setbyte(first_crc_byte_index, compressed.getbyte(first_crc_byte_index) ^ 0xff)

    assert_raises(Zlib::GzipFile::CRCError) do
      ActiveSupport::Gzip.decompress(compressed)
    end
  end
end
