require 'abstract_unit'

require 'active_support/core_ext/io'

class IOTest < Test::Unit::TestCase
  def test_binread_one_arg
    assert_equal File.read(__FILE__), IO.binread(__FILE__)
  end

  def test_binread_two_args
    assert_equal File.read(__FILE__).bytes.first(10).pack('C*'),
      IO.binread(__FILE__, 10)
  end

  def test_binread_three_args
    actual = IO.binread(__FILE__, 5, 10)
    expected = File.open(__FILE__, 'rb') { |f|
      f.seek 10
      f.read 5
    }
    assert_equal expected, actual
  end
end
