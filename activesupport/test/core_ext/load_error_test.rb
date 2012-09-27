require 'abstract_unit'
require 'active_support/core_ext/load_error'

class TestMissingSourceFile < ActiveSupport::TestCase
  def test_with_require
    assert_raise(MissingSourceFile) { require 'no_this_file_don\'t_exist' }
  end
  def test_with_load
    assert_raise(MissingSourceFile) { load 'nor_does_this_one' }
  end
  def test_path
    begin load 'nor/this/one.rb'
    rescue MissingSourceFile => e
      assert_equal 'nor/this/one.rb', e.path
    end
  end
end

class TestLoadError < ActiveSupport::TestCase
  def test_with_require
    assert_raise(LoadError) { require 'no_this_file_don\'t_exist' }
  end
  def test_with_load
    assert_raise(LoadError) { load 'nor_does_this_one' }
  end
  def test_path
    begin load 'nor/this/one.rb'
    rescue LoadError => e
      assert_equal 'nor/this/one.rb', e.path
    end
  end
end