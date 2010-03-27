require 'abstract_unit'

class ClassAttributeAccessorTest < Test::Unit::TestCase
  def setup
    @class = Class.new do
      cattr_accessor :foo
      cattr_accessor :bar,  :instance_writer => false
      cattr_reader   :shaq, :instance_reader => false
    end
    @object = @class.new
  end
  
  def test_should_use_mattr_default
    assert_nil @class.foo
    assert_nil @object.foo
  end
  
  def test_should_set_mattr_value
    @class.foo = :test
    assert_equal :test, @object.foo
  
    @object.foo = :test2
    assert_equal :test2, @class.foo
  end
  
  def test_should_not_create_instance_writer
    assert @class.respond_to?(:foo)
    assert @class.respond_to?(:foo=)
    assert @object.respond_to?(:bar)
    assert !@object.respond_to?(:bar=)
  end


  def test_should_not_create_instance_reader
    assert @class.respond_to?(:shaq)
    assert !@object.respond_to?(:shaq)
  end
end
