require 'abstract_unit'
require 'active_support/configurable'

class ConfigurableActiveSupport < ActiveSupport::TestCase
  class Parent
    include ActiveSupport::Configurable
    config_accessor :foo
    config_accessor :bar, instance_reader: false, instance_writer: false
    config_accessor :baz, instance_accessor: false
  end

  class Child < Parent
  end

  setup do
    Parent.config.clear
    Parent.config.foo = :bar

    Child.config.clear
  end

  test "adds a configuration hash" do
    assert_equal({ foo: :bar }, Parent.config)
  end

  test "adds a configuration hash to a module as well" do
    mixin = Module.new { include ActiveSupport::Configurable }
    mixin.config.foo = :bar
    assert_equal({ foo: :bar }, mixin.config)
  end

  test "configuration hash is inheritable" do
    assert_equal :bar, Child.config.foo
    assert_equal :bar, Parent.config.foo

    Child.config.foo = :baz
    assert_equal :baz, Child.config.foo
    assert_equal :bar, Parent.config.foo
  end

  test "configuration accessors is not available on instance" do
    instance = Parent.new

    assert !instance.respond_to?(:bar)
    assert !instance.respond_to?(:bar=)

    assert !instance.respond_to?(:baz)
    assert !instance.respond_to?(:baz=)
  end

  test "configuration accessors can take a default value" do
    parent = Class.new do
      include ActiveSupport::Configurable
      config_accessor :hair_colors, :tshirt_colors do
        [:black, :blue, :white]
      end
    end

    assert_equal [:black, :blue, :white], parent.hair_colors
    assert_equal [:black, :blue, :white], parent.tshirt_colors
  end

  test "configuration hash is available on instance" do
    instance = Parent.new
    assert_equal :bar, instance.config.foo
    assert_equal :bar, Parent.config.foo

    instance.config.foo = :baz
    assert_equal :baz, instance.config.foo
    assert_equal :bar, Parent.config.foo
  end

  test "configuration is crystalizeable" do
    parent = Class.new { include ActiveSupport::Configurable }
    child  = Class.new(parent)

    parent.config.bar = :foo
    assert_method_not_defined parent.config, :bar
    assert_method_not_defined child.config, :bar
    assert_method_not_defined child.new.config, :bar

    parent.config.compile_methods!
    assert_equal :foo, parent.config.bar
    assert_equal :foo, child.new.config.bar

    assert_method_defined parent.config, :bar
    assert_method_defined child.config, :bar
    assert_method_defined child.new.config, :bar
  end

  test "should raise name error if attribute name is invalid" do
    assert_raises NameError do
      Class.new do
        include ActiveSupport::Configurable
        config_accessor "invalid attribute name"
      end
    end
  end

  def assert_method_defined(object, method)
    methods = object.public_methods.map(&:to_s)
    assert methods.include?(method.to_s), "Expected #{methods.inspect} to include #{method.to_s.inspect}"
  end

  def assert_method_not_defined(object, method)
    methods = object.public_methods.map(&:to_s)
    assert !methods.include?(method.to_s), "Expected #{methods.inspect} to not include #{method.to_s.inspect}"
  end
end
