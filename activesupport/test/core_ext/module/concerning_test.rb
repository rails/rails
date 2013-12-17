require 'abstract_unit'
require 'active_support/core_ext/module/concerning'

class ConcerningTest < ActiveSupport::TestCase
  def test_concern_shortcut_creates_a_module_but_doesnt_include_it
    mod = Module.new { concern(:Foo) { } }
    assert_kind_of Module, mod::Foo
    assert mod::Foo.respond_to?(:included)
    assert !mod.ancestors.include?(mod::Foo), mod.ancestors.inspect
  end

  def test_concern_creates_a_module_extended_with_active_support_concern
    klass = Class.new do
      concern :Foo do
        included { @foo = 1 }
        def should_be_public; end
      end
    end

    # Declares a concern but doesn't include it
    assert_kind_of Module, klass::Foo
    assert !klass.ancestors.include?(klass::Foo), klass.ancestors.inspect

    # Public method visibility by default
    assert klass::Foo.public_instance_methods.map(&:to_s).include?('should_be_public')

    # Calls included hook
    assert_equal 1, Class.new { include klass::Foo }.instance_variable_get('@foo')
  end

  def test_concerning_declares_a_concern_and_includes_it_immediately
    klass = Class.new { concerning(:Foo) { } }
    assert klass.ancestors.include?(klass::Foo), klass.ancestors.inspect
  end
end
