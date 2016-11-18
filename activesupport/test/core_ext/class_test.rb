require "abstract_unit"
require "active_support/core_ext/class"
require "set"

class ClassTest < ActiveSupport::TestCase
  class Parent; end
  class Foo < Parent; end
  class Bar < Foo; end
  class Baz < Bar; end

  class A < Parent; end
  class B < A; end
  class C < B; end

  def test_descendants
    assert_equal [Foo, Bar, Baz, A, B, C].to_set, Parent.descendants.to_set
    assert_equal [Bar, Baz].to_set, Foo.descendants.to_set
    assert_equal [Baz], Bar.descendants
    assert_equal [], Baz.descendants
  end

  def test_subclasses
    assert_equal [Foo, A].to_set, Parent.subclasses.to_set
    assert_equal [Bar], Foo.subclasses
    assert_equal [Baz], Bar.subclasses
    assert_equal [], Baz.subclasses
  end
end
