# frozen_string_literal: true

require_relative "../../abstract_unit"
require "active_support/core_ext/class/attribute"

class UpdateHeritableValueOfTest < ActiveSupport::TestCase
  setup do
    @base = Class.new do
      class_attribute :settings, default: {}
    end

    @sub = Class.new(@base)
    @subsub = Class.new(@sub)
  end

  test "sets value" do
    @base.update_heritable_value_of(:settings, :foo, "base")

    assert_equal "base", @base.settings[:foo]
  end

  test "propagates value to subclasses" do
    @base.update_heritable_value_of(:settings, :foo, "base")

    assert_equal "base", @sub.settings[:foo]
    assert_equal "base", @subsub.settings[:foo]
  end

  test "propagates value to subclasses after subclass has been updated" do
    @sub.update_heritable_value_of(:settings, :bar, "sub")
    @base.update_heritable_value_of(:settings, :foo, "base")

    assert_equal "sub", @sub.settings[:bar]
    assert_equal "sub", @subsub.settings[:bar]
    assert_equal "base", @sub.settings[:foo]
    assert_equal "base", @subsub.settings[:foo]
  end

  test "does not set value in superclass" do
    @sub.update_heritable_value_of(:settings, :bar, "sub")

    assert_not_includes @base.settings, :bar
  end

  test "does not overwrite value set in subclass" do
    @sub.update_heritable_value_of(:settings, :bar, "sub")
    @base.update_heritable_value_of(:settings, :bar, "base")

    assert_equal "base", @base.settings[:bar]
    assert_equal "sub", @sub.settings[:bar]
    assert_equal "sub", @subsub.settings[:bar]
  end

  test "does not overwrite value set in subclass even when value was the same" do
    @base.update_heritable_value_of(:settings, :foo, :same)
    @sub.update_heritable_value_of(:settings, :foo, :same)
    @base.update_heritable_value_of(:settings, :foo, :new)

    assert_equal :new, @base.settings[:foo]
    assert_equal :same, @sub.settings[:foo]
    assert_equal :same, @subsub.settings[:foo]
  end

  test "avoids allocating a Hash when possible" do
    original_hash = @base.settings
    @base.update_heritable_value_of(:settings, :foo, "base")

    assert_same original_hash, @base.settings
    assert_same original_hash, @sub.settings
    assert_same original_hash, @subsub.settings
  end

  test "avoids allocating a bookkeeping object when possible" do
    @sub.update_heritable_value_of(:settings, :bar, "sub")

    assert @sub.settings.instance_variable_defined?(:@_class_attribute_inherited_keys)
    assert_nil @sub.settings.instance_variable_get(:@_class_attribute_inherited_keys)
  end
end
