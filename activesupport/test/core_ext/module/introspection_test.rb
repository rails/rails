require "abstract_unit"
require "active_support/core_ext/module/introspection"

module ParentA
  module B
    module C; end
    module FrozenC; end
    FrozenC.freeze
  end

  module FrozenB; end
  FrozenB.freeze
end

class IntrospectionTest < ActiveSupport::TestCase
  def test_parent_name
    assert_equal "ParentA", ParentA::B.parent_name
    assert_equal "ParentA::B", ParentA::B::C.parent_name
    assert_nil ParentA.parent_name
  end

  def test_parent_name_when_frozen
    assert_equal "ParentA", ParentA::FrozenB.parent_name
    assert_equal "ParentA::B", ParentA::B::FrozenC.parent_name
  end

  def test_parent
    assert_equal ParentA::B, ParentA::B::C.parent
    assert_equal ParentA, ParentA::B.parent
    assert_equal Object, ParentA.parent
  end

  def test_parents
    assert_equal [ParentA::B, ParentA, Object], ParentA::B::C.parents
    assert_equal [ParentA, Object], ParentA::B.parents
  end
end
