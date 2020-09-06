# frozen_string_literal: true

require_relative '../../abstract_unit'
require 'active_support/core_ext/module/concerning'

class ModuleConcerningTest < ActiveSupport::TestCase
  def test_concerning_declares_a_concern_and_includes_it_immediately
    klass = Class.new { concerning(:Foo) { } }
    assert_includes klass.ancestors, klass::Foo, klass.ancestors.inspect

    klass = Class.new { concerning(:Foo, prepend: true) { } }
    assert_includes klass.ancestors, klass::Foo, klass.ancestors.inspect
  end

  def test_concerning_can_prepend_concern
    klass = Class.new do
      def hi; 'self'; end

      concerning(:Foo, prepend: true) do
        def hi; "hello, #{super}"; end
      end
    end

    assert_equal 'hello, self', klass.new.hi
  end
end

class ModuleConcernTest < ActiveSupport::TestCase
  def test_concern_creates_a_module_extended_with_active_support_concern
    klass = Class.new do
      concern :Baz do
        included { @foo = 1 }
        prepended { @foo = 2 }
        def should_be_public; end
      end
    end

    # Declares a concern but doesn't include it
    assert klass.const_defined?(:Baz, false)
    assert_not ModuleConcernTest.const_defined?(:Baz)
    assert_kind_of ActiveSupport::Concern, klass::Baz
    assert_not_includes klass.ancestors, klass::Baz, klass.ancestors.inspect

    # Public method visibility by default
    assert_includes klass::Baz.public_instance_methods.map(&:to_s), 'should_be_public'

    # Calls included hook
    assert_equal 1, Class.new { include klass::Baz }.instance_variable_get('@foo')

    # Calls prepended hook
    assert_equal 2, Class.new { prepend klass::Baz }.instance_variable_get('@foo')
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

    concerning :Baz, prepend: true do
      module ClassMethods
        def will_be_orphaned_also; end
      end

      const_set :ClassMethods, Module.new {
        def hacked_on_also; end
      }

      # Doesn't overwrite existing ClassMethods module.
      class_methods do
        def nicer_dsl_also; end
      end

      # Doesn't overwrite previous class_methods definitions.
      class_methods do
        def doesnt_clobber_also; end
      end
    end
  end

  def test_using_class_methods_blocks_instead_of_ClassMethods_module
    assert_not_respond_to Foo, :will_be_orphaned
    assert_respond_to Foo, :hacked_on
    assert_respond_to Foo, :nicer_dsl
    assert_respond_to Foo, :doesnt_clobber

    # Orphan in Foo::ClassMethods, not Bar::ClassMethods.
    assert Foo.const_defined?(:ClassMethods)
    assert Foo::ClassMethods.method_defined?(:will_be_orphaned)
  end

  def test_using_class_methods_blocks_instead_of_ClassMethods_module_prepend
    assert_not_respond_to Foo, :will_be_orphaned_also
    assert_respond_to Foo, :hacked_on_also
    assert_respond_to Foo, :nicer_dsl_also
    assert_respond_to Foo, :doesnt_clobber_also

    # Orphan in Foo::ClassMethods, not Bar::ClassMethods.
    assert Foo.const_defined?(:ClassMethods)
    assert Foo::ClassMethods.method_defined?(:will_be_orphaned_also)
  end
end
