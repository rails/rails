# frozen_string_literal: true

require_relative "../abstract_unit"
require "active_support/core_ext/class"
require "active_support/descendants_tracker"

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

  def test_descendants_excludes_singleton_classes
    klass = Parent.new.singleton_class
    assert_not Parent.descendants.include?(klass), "descendants should not include singleton classes"
  end

  def test_subclasses_excludes_singleton_classes
    klass = Parent.new.singleton_class
    assert_not Parent.subclasses.include?(klass), "subclasses should not include singleton classes"
  end

  def test_subclasses_exclude_reloaded_classes
    subclass = Class.new(Parent)
    assert_includes Parent.subclasses, subclass
    ActiveSupport::DescendantsTracker.clear(Set[subclass])
    assert_not_includes Parent.subclasses, subclass
  end

  def test_descendants_exclude_reloaded_classes
    subclass = Class.new(Parent)
    assert_includes Parent.descendants, subclass
    ActiveSupport::DescendantsTracker.clear(Set[subclass])
    assert_not_includes Parent.descendants, subclass
  end
end
