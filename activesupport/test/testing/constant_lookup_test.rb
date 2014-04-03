require 'abstract_unit'
require 'dependencies_test_helpers'

class Foo; end
class Bar < Foo
  def index; end
  def self.index; end
end
module FooBar; end

class ConstantLookupTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::ConstantLookup
  include DependenciesTestHelpers

  def find_foo(name)
    self.class.determine_constant_from_test_name(name) do |constant|
      Class === constant && constant < Foo
    end
  end

  def find_module(name)
    self.class.determine_constant_from_test_name(name) do |constant|
      Module === constant
    end
  end

  def test_find_bar_from_foo
    assert_equal Bar, find_foo("Bar")
  end

  def test_find_module
    assert_equal FooBar, find_module("FooBar")
  end

  def test_does_not_swallow_exception_on_no_method_error
    assert_raises(NoMethodError) {
      with_autoloading_fixtures {
        self.class.determine_constant_from_test_name("RaisesNoMethodError")
      }
    }
  end

  def test_does_not_swallow_exception_on_name_error
    assert_raises(NameError) {
      with_autoloading_fixtures {
        self.class.determine_constant_from_test_name('RaisesNameError')
      }
    }
  end
end
