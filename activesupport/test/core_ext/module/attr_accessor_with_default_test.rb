require 'abstract_unit'
require 'active_support/core_ext/module/attr_accessor_with_default'

class AttrAccessorWithDefaultTest < ActiveSupport::TestCase
  def setup
    @target = Class.new do
      def helper
        'helper'
      end
    end
    @instance = @target.new
  end

  def test_default_arg
    assert_deprecated do
      @target.attr_accessor_with_default :foo, :bar
    end
    assert_equal(:bar, @instance.foo)
    @instance.foo = nil
    assert_nil(@instance.foo)
  end

  def test_default_proc
    assert_deprecated do
      @target.attr_accessor_with_default(:foo) {helper.upcase}
    end
    assert_equal('HELPER', @instance.foo)
    @instance.foo = nil
    assert_nil(@instance.foo)
  end

  def test_invalid_args
    assert_raise(ArgumentError) do
      assert_deprecated do
        @target.attr_accessor_with_default :foo
      end
    end
  end
end
