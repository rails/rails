require 'abstract_unit'
require 'active_support/core_ext/module/attr_internal'

class AttrInternalTest < ActiveSupport::TestCase
  def setup
    @target = Class.new
    @instance = @target.new
  end

  def test_reader
    @target.attr_internal_reader :foo

    assert !@instance.instance_variable_defined?('@_foo')
    assert_raise(NoMethodError) { @instance.foo = 1 }

    @instance.instance_variable_set('@_foo', 1)
    assert_equal 1, @instance.foo
  end

  def test_writer
    @target.attr_internal_writer :foo

    assert !@instance.instance_variable_defined?('@_foo')
    assert_equal 1, @instance.foo = 1

    assert_equal 1, @instance.instance_variable_get('@_foo')
    assert_raise(NoMethodError) { @instance.foo }
  end

  def test_accessor
    @target.attr_internal :foo

    assert !@instance.instance_variable_defined?('@_foo')
    assert_equal 1, @instance.foo = 1

    assert_equal 1, @instance.instance_variable_get('@_foo')
    assert_equal 1, @instance.foo
  end

  def test_naming_format
    assert_equal '@_%s', Module.attr_internal_naming_format
    Module.attr_internal_naming_format = '@abc%sdef'
    @target.attr_internal :foo

    assert !@instance.instance_variable_defined?('@_foo')
    assert !@instance.instance_variable_defined?('@abcfoodef')
    @instance.foo = 1
    assert !@instance.instance_variable_defined?('@_foo')
    assert @instance.instance_variable_defined?('@abcfoodef')
  ensure
    Module.attr_internal_naming_format = '@_%s'
  end
end
