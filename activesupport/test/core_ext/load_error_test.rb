require 'abstract_unit'

class TestMissingSourceFile < Test::Unit::TestCase
  def test_with_require
    assert_raises(MissingSourceFile) { require 'no_this_file_don\'t_exist' }
  end
  def test_with_load
    assert_raises(MissingSourceFile) { load 'nor_does_this_one' }
  end
  def test_path
    begin load 'nor/this/one.rb'
    rescue MissingSourceFile => e
      assert_equal 'nor/this/one.rb', e.path
    end
  end
end
