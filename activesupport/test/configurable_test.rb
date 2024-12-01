# frozen_string_literal: true

require_relative "abstract_unit"
require "active_support/configurable"

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

  test "Class-level configuration hash is writable" do
    assert_changes -> { Child.config.foo }, from: :bar, to: :baz do
      Child.config = { foo: :baz }
    end
    assert_kind_of ActiveSupport::Configurable::Configuration, Child.config
    assert_equal :baz, Child.new.foo

    assert_changes -> { Child.config.foo }, from: :baz, to: :qux do
      Child.config = ActiveSupport::InheritableOptions.new(foo: :qux)
    end
    assert_kind_of ActiveSupport::Configurable::Configuration, Child.config
    assert_equal :qux, Child.new.foo

    assert_changes -> { Child.config.foo }, from: :qux, to: :bar do
      Child.config = nil
    end
    assert_kind_of ActiveSupport::Configurable::Configuration, Child.config
    assert_equal :bar, Child.new.foo

    assert_raises ArgumentError, match: %(value "junk" does not respond to #to_h) do
      Child.config = "junk"
    end
  end

  test "instance-level configuration hash is writable" do
    child = Child.new

    assert_changes -> { child.config.foo }, from: :bar, to: :baz do
      child.config = { foo: :baz }
    end
    assert_kind_of ActiveSupport::Configurable::Configuration, child.config
    assert_equal :baz, child.foo

    assert_changes -> { child.config.foo }, from: :baz, to: :qux do
      child.config = ActiveSupport::InheritableOptions.new(foo: :qux)
    end
    assert_kind_of ActiveSupport::Configurable::Configuration, child.config
    assert_equal :qux, child.foo

    assert_changes -> { child.config.foo }, from: :qux, to: :bar do
      child.config = nil
    end
    assert_kind_of ActiveSupport::Configurable::Configuration, child.config
    assert_equal Child.config, child.config

    assert_raises ArgumentError, match: %(value "junk" does not respond to #to_h) do
      child.config = "junk"
    end
  end

  test "configuration accessors are not available on instance" do
    instance = Parent.new

    assert_not_respond_to instance, :bar
    assert_not_respond_to instance, :bar=

    assert_not_respond_to instance, :baz
    assert_not_respond_to instance, :baz=
  end

  test "configuration accessors can take a default value as a block" do
    parent = Class.new do
      include ActiveSupport::Configurable
      config_accessor :hair_colors, :tshirt_colors do
        [:black, :blue, :white]
      end
    end

    assert_equal [:black, :blue, :white], parent.hair_colors
    assert_equal [:black, :blue, :white], parent.tshirt_colors
  end

  test "configuration accessors can take a default value as an option" do
    parent = Class.new do
      include ActiveSupport::Configurable
      config_accessor :foo, default: :bar
    end

    assert_equal :bar, parent.foo
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

    assert_raises NameError do
      Class.new do
        include ActiveSupport::Configurable
        config_accessor "invalid\nattribute"
      end
    end

    assert_raises NameError do
      Class.new do
        include ActiveSupport::Configurable
        config_accessor "invalid\n"
      end
    end
  end

  test "the config_accessor method should not be publicly callable" do
    assert_raises NoMethodError do
      Class.new {
        include ActiveSupport::Configurable
      }.config_accessor :foo
    end
  end

  def assert_method_defined(object, method)
    methods = object.public_methods.map(&:to_s)
    assert_includes methods, method.to_s, "Expected #{methods.inspect} to include #{method.to_s.inspect}"
  end

  def assert_method_not_defined(object, method)
    methods = object.public_methods.map(&:to_s)
    assert_not_includes methods, method.to_s, "Expected #{methods.inspect} to not include #{method.to_s.inspect}"
  end
end
