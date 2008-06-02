require 'abstract_unit'

class GzipTest < Test::Unit::TestCase
  def test_compress_should_decompress_to_the_same_value
    assert_equal "Hello World", ActiveSupport::Gzip.decompress(ActiveSupport::Gzip.compress("Hello World"))
  end
end