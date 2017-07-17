# frozen_string_literal: true

require "abstract_unit"
require "active_support/core_ext/module/concerning"

class ModuleConcerningTest < ActiveSupport::TestCase
  def test_concerning_declares_a_concern_and_includes_it_immediately
    klass = Class.new { concerning(:Foo) {} }
    assert_includes klass.ancestors, klass::Foo, klass.ancestors.inspect
  end
end

class ModuleConcernTest < ActiveSupport::TestCase
  def test_concern_creates_a_module_extended_with_active_support_concern
    klass = Class.new do
      concern :Baz do
        included { @foo = 1 }
        def should_be_public; end
      end
    end

    # Declares a concern but doesn't include it
    assert klass.const_defined?(:Baz, false)
    assert !ModuleConcernTest.const_defined?(:Baz)
    assert_kind_of ActiveSupport::Concern, klass::Baz
    assert_not_includes klass.ancestors, klass::Baz, klass.ancestors.inspect

    # Public method visibility by default
    assert_includes klass::Baz.public_instance_methods.map(&:to_s), "should_be_public"

    # Calls included hook
    assert_equal 1, Class.new { include klass::Baz }.instance_variable_get("@foo")
  end

  class Foo
    concerning :Bar do
      module ClassMethods
        def will_be_orphaned; end
      end

      const_set :ClassMethods, Module.new {
        def hacked_on; end
      }

      # Doesn't overwrite existing ClassMethods module.
      class_methods do
        def nicer_dsl; end
      end

      # Doesn't overwrite previous class_methods definitions.
      class_methods do
        def doesnt_clobber; end
      end
    end
  end

  def test_using_class_methods_blocks_instead_of_ClassMethods_module
    assert !Foo.respond_to?(:will_be_orphaned)
    assert Foo.respond_to?(:hacked_on)
    assert Foo.respond_to?(:nicer_dsl)
    assert Foo.respond_to?(:doesnt_clobber)

    # Orphan in Foo::ClassMethods, not Bar::ClassMethods.
    assert Foo.const_defined?(:ClassMethods)
    assert Foo::ClassMethods.method_defined?(:will_be_orphaned)
  end
end
