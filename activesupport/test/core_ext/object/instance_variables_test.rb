# frozen_string_literal: true

require "abstract_unit"
require "active_support/core_ext/object"

class ObjectInstanceVariableTest < ActiveSupport::TestCase
  def setup
    @source, @dest = Object.new, Object.new
    @source.instance_variable_set(:@bar, "bar")
    @source.instance_variable_set(:@baz, "baz")
  end

  def test_instance_variable_names
    assert_equal %w(@bar @baz), @source.instance_variable_names.sort
  end

  def test_instance_values
    assert_equal({ "bar" => "bar", "baz" => "baz" }, @source.instance_values)
  end

  def test_instance_exec_passes_arguments_to_block
    assert_equal %w(hello goodbye), (+"hello").instance_exec("goodbye") { |v| [self, v] }
  end

  def test_instance_exec_with_frozen_obj
    assert_equal %w(olleh goodbye), "hello".instance_exec("goodbye") { |v| [reverse, v] }
  end

  def test_instance_exec_nested
    assert_equal %w(goodbye olleh bar), (+"hello").instance_exec("goodbye") { |arg|
      [arg] + instance_exec("bar") { |v| [reverse, v] } }
  end
end
