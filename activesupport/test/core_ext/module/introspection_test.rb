# frozen_string_literal: true

require_relative "../../abstract_unit"
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

  def test_module_parent_name_notice_changes
    klass = Class.new
    assert_nil klass.module_parent_name
    ParentA.const_set(:NewClass, klass)
    assert_equal "ParentA", klass.module_parent_name
  ensure
    ParentA.send(:remove_const, :NewClass) if ParentA.const_defined?(:NewClass)
  end

  def test_module_parent
    assert_equal ParentA::B, ParentA::B::C.module_parent
    assert_equal ParentA, ParentA::B.module_parent
    assert_equal Object, ParentA.module_parent
  end

  def test_module_parents
    assert_equal [ParentA::B, ParentA, Object], ParentA::B::C.module_parents
    assert_equal [ParentA, Object], ParentA::B.module_parents
  end

  def test_module_parent_notice_changes
    klass = Class.new
    assert_equal Object, klass.module_parent
    ParentA.const_set(:NewClass, klass)
    assert_equal ParentA, klass.module_parent
  ensure
    ParentA.send(:remove_const, :NewClass) if ParentA.const_defined?(:NewClass)
  end
end
