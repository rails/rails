require File.dirname(__FILE__) + '/../../abstract_unit'

class AttrWithDefaultTest < Test::Unit::TestCase
  def setup
    @target = Class.new do
      def helper
        'helper'
      end
    end  
    @instance = @target.new
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
    assert_raise(RuntimeError) {@target.attr_accessor_with_default :foo}
  end
end