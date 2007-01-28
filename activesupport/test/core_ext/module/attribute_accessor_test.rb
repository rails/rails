require File.dirname(__FILE__) + '/../../abstract_unit'

class ModuleAttributeAccessorTest < Test::Unit::TestCase
  def setup
    @module = Module.new do
      mattr_accessor :foo
      mattr_accessor :bar, :instance_writer => false
    end
    @class = Class.new
    @class.send :include, @module
    @object = @class.new
  end
  
  def test_should_use_mattr_default
    assert_nil @module.foo
    assert_nil @object.foo
  end
  
  def test_should_set_mattr_value
    @module.foo = :test
    assert_equal :test, @object.foo
  
    @object.foo = :test2
    assert_equal :test2, @module.foo
  end
  
  def test_should_not_create_instance_writer
    assert @module.respond_to?(:foo)
    assert @module.respond_to?(:foo=)
    assert @object.respond_to?(:bar)
    assert !@object.respond_to?(:bar=)
  end
end