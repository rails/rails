# frozen_string_literal: true

require_relative "../../abstract_unit"
require "active_support/core_ext/module/attr_internal"

class AttrInternalTest < ActiveSupport::TestCase
  def setup
    @target = Class.new
    @instance = @target.new
    @naming_format_was = Module.attr_internal_naming_format
  end

  def teardown
    Module.attr_internal_naming_format = @naming_format_was
  end

  def test_reader
    assert_nothing_raised { @target.attr_internal_reader :foo }

    assert_not @instance.instance_variable_defined?("@_foo")
    assert_raise(NoMethodError) { @instance.foo = 1 }

    @instance.instance_variable_set("@_foo", 1)
    assert_nothing_raised { assert_equal 1, @instance.foo }
  end

  def test_writer
    assert_nothing_raised { @target.attr_internal_writer :foo }

    assert_not @instance.instance_variable_defined?("@_foo")
    assert_nothing_raised { assert_equal 1, @instance.foo = 1 }

    assert_equal 1, @instance.instance_variable_get("@_foo")
    assert_raise(NoMethodError) { @instance.foo }
  end

  def test_accessor
    assert_nothing_raised { @target.attr_internal :foo }

    assert_not @instance.instance_variable_defined?("@_foo")
    assert_nothing_raised { assert_equal 1, @instance.foo = 1 }

    assert_equal 1, @instance.instance_variable_get("@_foo")
    assert_nothing_raised { assert_equal 1, @instance.foo }
  end

  def test_invalid_naming_format
    assert_equal "_%s", Module.attr_internal_naming_format
    assert_raises(ArgumentError) do
      Module.attr_internal_naming_format = "@___%s"
    end
  end

  def test_naming_format
    assert_nothing_raised { Module.attr_internal_naming_format = "abc%sdef" }
    @target.attr_internal :foo

    assert_not @instance.instance_variable_defined?("@_foo")
    assert_not @instance.instance_variable_defined?("@abcfoodef")
    assert_nothing_raised { @instance.foo = 1 }
    assert_not @instance.instance_variable_defined?("@_foo")
    assert @instance.instance_variable_defined?("@abcfoodef")
  end
end
