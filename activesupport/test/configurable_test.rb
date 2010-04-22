require 'abstract_unit'
require 'active_support/configurable'

class ConfigurableActiveSupport < ActiveSupport::TestCase
  class Parent
    include ActiveSupport::Configurable
    config_accessor :foo
  end

  class Child < Parent
  end

  setup do
    Parent.config.clear
    Parent.config.foo = :bar

    Child.config.clear
  end

  test "adds a configuration hash" do
    assert_equal({ :foo => :bar }, Parent.config)
  end

  test "configuration hash is inheritable" do
    assert_equal :bar, Child.config.foo
    assert_equal :bar, Parent.config.foo

    Child.config.foo = :baz
    assert_equal :baz, Child.config.foo
    assert_equal :bar, Parent.config.foo
  end

  test "configuration hash is available on instance" do
    instance = Parent.new
    assert_equal :bar, instance.config.foo
    assert_equal :bar, Parent.config.foo

    instance.config.foo = :baz
    assert_equal :baz, instance.config.foo
    assert_equal :bar, Parent.config.foo
  end
end