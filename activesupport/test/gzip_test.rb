require 'abstract_unit'
require 'active_support/core_ext/object/blank'

class GzipTest < ActiveSupport::TestCase
  def test_compress_should_decompress_to_the_same_value
    assert_equal "Hello World", ActiveSupport::Gzip.decompress(ActiveSupport::Gzip.compress("Hello World"))
  end

  def test_compress_should_return_a_binary_string
    compressed = ActiveSupport::Gzip.compress('')

    assert_equal Encoding.find('binary'), compressed.encoding
    assert !compressed.blank?, "a compressed blank string should not be blank"
  end
end
