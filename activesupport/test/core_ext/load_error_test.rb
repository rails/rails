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
  def test_is_missing
    begin load 'nor/that/one.rb'
    rescue LoadError => e
      assert_equal e.is_missing?('nor/that/one'), true
    end
  end
  def test_is_missing_with_nil_path
    begin load 'nor/any/one.rb'
    rescue LoadError => e
      e.stubs(:path).returns(nil)
      assert_equal e.is_missing?('nor/any/one'), true
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
  def test_is_missing
    begin load 'nor/that/one.rb'
    rescue LoadError => e
      assert_equal e.is_missing?('nor/that/one'), true
    end
  end
  def test_is_missing_with_nil_path
    begin load 'nor/any/one.rb'
    rescue LoadError => e
      e.stubs(:path).returns(nil)
      assert_equal e.is_missing?('nor/any/one'), true
    end
  end
end
