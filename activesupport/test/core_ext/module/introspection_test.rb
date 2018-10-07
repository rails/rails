# frozen_string_literal: true

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
  def test_module_parent_name
    assert_equal "ParentA", ParentA::B.module_parent_name
    assert_equal "ParentA::B", ParentA::B::C.module_parent_name
    assert_nil ParentA.module_parent_name
  end

  def test_module_parent_name_when_frozen
    assert_equal "ParentA", ParentA::FrozenB.module_parent_name
    assert_equal "ParentA::B", ParentA::B::FrozenC.module_parent_name
  end

  def test_parent_name
    assert_deprecated do
      assert_equal "ParentA", ParentA::B.parent_name
    end
  end

  def test_module_parent
    assert_equal ParentA::B, ParentA::B::C.module_parent
    assert_equal ParentA, ParentA::B.module_parent
    assert_equal Object, ParentA.module_parent
  end

  def test_parent
    assert_deprecated do
      assert_equal ParentA, ParentA::B.parent
    end
  end

  def test_module_parents
    assert_equal [ParentA::B, ParentA, Object], ParentA::B::C.module_parents
    assert_equal [ParentA, Object], ParentA::B.module_parents
  end

  def test_parents
    assert_deprecated do
      assert_equal [ParentA, Object], ParentA::B.parents
    end
  end
end
