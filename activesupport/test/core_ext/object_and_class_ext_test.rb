require 'test/unit'
require File.dirname(__FILE__) + '/../../lib/core_ext/object_and_class'

class A; end
class B < A; end
class C < B; end
class D < A; end

class ClassExtTest < Test::Unit::TestCase
  def test_methods
    assert defined?(B)
    assert defined?(C)
    assert defined?(D)

    A.remove_subclasses

    assert !defined?(B)
    assert !defined?(C)
    assert !defined?(D)
  end
end
