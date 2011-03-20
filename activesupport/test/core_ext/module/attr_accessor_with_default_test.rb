require 'abstract_unit'
require 'active_support/core_ext/module/attr_accessor_with_default'

class AttrAccessorWithDefaultTest < Test::Unit::TestCase
  def setup
    @target = Class.new do
      def helper
        'helper'
      end
    end
    self.class.const_set(:TestClass, @target)
    @instance = @target.new
  end

  def teardown
    self.class.send(:remove_const, :TestClass)
  end

  def test_default_arg
    @target.attr_accessor_with_default :foo, :bar
    assert_equal(:bar, @instance.foo)
    @instance.foo = nil
    assert_nil(@instance.foo)
  end

  def test_default_proc
    @target.attr_accessor_with_default(:foo) {helper.upcase}
    assert_equal('HELPER', @instance.foo)
    @instance.foo = nil
    assert_nil(@instance.foo)
  end

  def test_invalid_args
    assert_raise(ArgumentError) {@target.attr_accessor_with_default :foo}
  end

  def test_instance_with_value_set_can_be_marshaled
    @target.attr_accessor_with_default(:foo, 'default')
    @instance.foo = 'Hi'
    assert_nothing_raised { Marshal.dump(@instance) }
  end
end
